import Matter from 'matter-js'
import { ViewHook } from 'phoenix_live_view'

import SOCKET from '../socket'
import UUID from '../uuid'
import WORLD from './world'

// color of a locked block
const LOCK_COLOR = '#e2e8f0'

// constant for lerping
const LERP_ALPHA = 0.2

// maximum speed of any body
const MAX_SPEED = 25

// client tick for sending updates
const TICK = 100

export default class PhysicsCanvas extends ViewHook {
  mounted() {
    // holds lock state for each block
    this.lockedByOthers = new Set()
    this.lockedByMe = new Set()
    this.previouslyLockedByMe = new Set()

    // holds tick for update changes
    this.lastSent = 0

    this.connect()
    this.setupRenderer()

    Matter.Events.on(WORLD.ENGINE, 'beforeUpdate', (_event) => {
      this.onBeforeUpdate()
    })

    Matter.Events.on(this.mouseConstraint, 'startdrag', (event) => {
      this.onStartDrag(event)
    })

    Matter.Events.on(this.mouseConstraint, 'enddrag', (event) => {
      this.onEndDrag(event)
    })

    this.channel.on('lock-block', (payload) => {
      this.onLockBlock(payload)
    })

    this.channel.on('unlock-block', (payload) => {
      this.onUnlockBlock(payload)
    })

    Matter.Events.on(WORLD.ENGINE, 'afterUpdate', () => this.onAfterUpdate())

    this.channel.on('block-update', (payload) => {
      this.onBlockUpdate(payload)
    })
  }

  buildBroadcastPosition(body, label) {
    return {
      x: body.position.x,
      y: body.position.y,
      xNormalized: WORLD.normalizeWidth(body.position.x),
      yNormalized: WORLD.normalizeHeight(body.position.y),
      label,
    }
  }

  lerpToTarget(body, target) {
    Matter.Sleeping.set(body, false)
    Matter.Body.setVelocity(body, {
      x: (target.x - body.position.x) * LERP_ALPHA,
      y: (target.y - body.position.y) * LERP_ALPHA,
    })
  }

  connect() {
    this.peerId = UUID
    this.channel = SOCKET.channel('physics:lobby', {})
    this.channel
      .join()
      .receive('ok', ({ blocks }) => {
        this.setupInitialServerBlockState(blocks)
      })
      .receive('error', (response) => {
        console.error('Unable to join physics room', response)
      })
  }

  setupInitialServerBlockState(blocks) {
    this.blocks = {}
    for (const block of blocks) {
      const { label, xNormalized, yNormalized, lockedBy, color } = block
      const x = WORLD.denormalizeWidth(xNormalized)
      const y = WORLD.denormalizeHeight(yNormalized)
      const body = WORLD.createBlock({
        label,
        color,
        x,
        y,
      })
      console.log(block)
      this.blocks[block.label] = {
        originalColor: color,
        body,
      }
      Matter.World.add(WORLD.ENGINE.world, body)

      Matter.Body.setVelocity(body, { x: 0, y: 0 })
      if (lockedBy) {
        this.lockBlock(label, lockedBy)
      }
    }
  }

  lockBlock(label, by) {
    if (by === this.peerId) {
      return
    }
    this.previouslyLockedByMe.delete(label)
    this.lockedByOthers.add(label)
    this.blocks[label].body.render.fillStyle = LOCK_COLOR
  }

  unlockBlock(label, by) {
    if (by === this.peerId) {
      return
    }
    this.lockedByOthers.delete(label)
    this.blocks[label].body.render.fillStyle = this.blocks[label].originalColor
  }

  setupRenderer() {
    const render = Matter.Render.create({
      engine: WORLD.ENGINE,
      element: this.el,
      options: WORLD.RENDER_OPTIONS,
    })
    Matter.Render.run(render)
    Matter.Runner.run(WORLD.RUNNER, WORLD.ENGINE)

    Matter.World.add(WORLD.ENGINE.world, WORLD.WALLS)

    const mouse = Matter.Mouse.create(render.canvas)
    this.mouseConstraint = Matter.MouseConstraint.create(WORLD.ENGINE, {
      mouse,
      constraint: {
        stiffness: 0.1,
        damping: 0.05,
        render: {
          visible: false,
        },
      },
    })
    Matter.World.add(WORLD.ENGINE.world, this.mouseConstraint)
  }

  onStartDrag(event) {
    if (this.lockedByOthers.has(event.body.label)) {
      this.stopDrag()
      return
    }
    this.previouslyLockedByMe.delete(event.body.label)
    this.blocks[event.body.label].target = null
    this.lockedByMe.add(event.body.label)
    this.channel.push('lock-block', {
      block: event.body.label,
      by: this.peerId,
    })
  }

  onEndDrag(event) {
    if (this.lockedByOthers.has(event.body.label)) {
      this.stopDrag()
      return
    }
    Matter.Body.setAngularVelocity(event.body, 0)
    this.blocks[event.body.label].target = null
    this.lockedByMe.delete(event.body.label)
    this.previouslyLockedByMe.add(event.body.label)
    this.channel.push('unlock-block', {
      block: event.body.label,
      by: this.peerId,
    })
  }

  stopDrag() {
    this.mouseConstraint.constraint.bodyB = null
    this.mouseConstraint.constraint.pointB = null
    this.mouseConstraint.body = null
  }

  onLockBlock(payload) {
    this.lockBlock(payload.block, payload.by)
  }

  onUnlockBlock(payload) {
    this.unlockBlock(payload.block, payload.by)
  }

  onAfterUpdate() {
    const now = Date.now()
    if (now - this.lastSent < TICK) {
      return
    }
    this.lastSent = now

    const payload = {
      by: this.peerId,
      changes: [],
    }
    for (const [label, { body, target }] of Object.entries(this.blocks)) {
      if (this.lockedByMe.has(label) || this.previouslyLockedByMe.has(label)) {
        payload.changes.push(this.buildBroadcastPosition(body, label))
      } else if (target) {
        this.lerpToTarget(body, target)
      }
    }
    if (payload.changes.length > 0) {
      this.channel.push('block-update', payload)
    }
  }

  onBlockUpdate(payload) {
    if (payload.by === this.peerId) return
    for (const change of payload.changes) {
      const block = this.blocks[change.label]
      block.target = { x: change.x, y: change.y }

      // Kill existing velocity so the LERP is the only thing moving it
      Matter.Body.setVelocity(block.body, { x: 0, y: 0 })
    }
  }

  onBeforeUpdate() {
    // Check if the mouse is currently holding a body
    const draggedBody = this.mouseConstraint.body

    if (draggedBody) {
      const speed = Matter.Vector.magnitude(draggedBody.velocity)
      if (speed > MAX_SPEED) {
        const unitVector = Matter.Vector.normalise(draggedBody.velocity)
        Matter.Body.setVelocity(
          draggedBody,
          Matter.Vector.mult(unitVector, MAX_SPEED),
        )
      }
    }
  }
}
