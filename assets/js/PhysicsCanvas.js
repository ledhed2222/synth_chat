import Matter from 'matter-js'
import { ViewHook } from 'phoenix_live_view'

import SOCKET from './socket'
import UUID from './uuid'

const WIDTH = 800
const HEIGHT = 800
const RENDER_OPTIONS = {
  width: WIDTH,
  height: HEIGHT,
  wireframes: false,
}
const ENGINE = Matter.Engine.create()
ENGINE.gravity = {
  x: 0,
  y: 0,
  scale: 0,
}
const RUNNER = Matter.Runner.create()

const BLOCKS = [
  { label: 'frequency', x: WIDTH / 2, y: 100, color: '#d79921' },
  { label: 'filterCutoff', x: WIDTH / 2 - 100, y: 100, color: '#ff80ed' },
]

const WALL_THICKNESS = 50
// TODO Boundaries instead?
const WALLS = [
  // floor
  Matter.Bodies.rectangle(
    WIDTH / 2,
    HEIGHT + WALL_THICKNESS / 2,
    WIDTH,
    WALL_THICKNESS,
    { isStatic: true },
  ),
  // ceiling
  Matter.Bodies.rectangle(
    WIDTH / 2,
    -WALL_THICKNESS / 2,
    WIDTH,
    WALL_THICKNESS,
    { isStatic: true },
  ),
  // left
  Matter.Bodies.rectangle(
    -WALL_THICKNESS / 2,
    HEIGHT / 2,
    WALL_THICKNESS,
    HEIGHT,
    { isStatic: true },
  ),
  // right
  Matter.Bodies.rectangle(
    WIDTH + WALL_THICKNESS / 2,
    HEIGHT / 2,
    WALL_THICKNESS,
    HEIGHT,
    { isStatic: true },
  ),
]

// Normalize a position value to 0.0–1.0 within the canvas bounds
function normalize(value, max) {
  return Math.min(1, Math.max(0, value / max))
}

function createBlock({ label, x, y, color }) {
  return Matter.Bodies.rectangle(x, y, 50, 50, {
    label,
    render: { fillStyle: color },
    inertia: Infinity,
  })
}

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
    this.buildBlocks()

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

    Matter.Events.on(ENGINE, 'afterUpdate', () => this.onAfterUpdate())

    this.channel.on('block-update', (payload) => {
      this.onBlockUpdate(payload)
    })
  }

  buildBroadcastPosition(body, label) {
    return {
      x: body.position.x,
      y: body.position.y,
      xNormalized: normalize(body.position.x, WIDTH),
      yNormalized: normalize(body.position.y, HEIGHT),
      label,
    }
  }

  lerpToTarget(body, target) {
    const alpha = 0.2
    Matter.Body.setPosition(body, {
      x: body.position.x + (target.x - body.position.x) * alpha,
      y: body.position.y + (target.y - body.position.y) * alpha,
    })
  }

  connect() {
    this.peerId = UUID
    this.channel = SOCKET.channel('physics:lobby', {})
    this.channel
      .join()
      .receive('ok', (response) => {
        console.log('Joined physics room successfully', response)
      })
      .receive('error', (response) => {
        console.log('Unable to join physics room', response)
      })
  }

  setupRenderer() {
    const render = Matter.Render.create({
      engine: ENGINE,
      element: this.el,
      options: RENDER_OPTIONS,
    })
    Matter.Render.run(render)
    Matter.Runner.run(RUNNER, ENGINE)

    Matter.World.add(ENGINE.world, WALLS)

    const mouse = Matter.Mouse.create(render.canvas)
    this.mouseConstraint = Matter.MouseConstraint.create(ENGINE, { mouse })
    Matter.World.add(ENGINE.world, this.mouseConstraint)
  }

  buildBlocks() {
    this.blocks = {}
    for (const block of BLOCKS) {
      const body = createBlock(block)
      this.blocks[block.label] = {
        originalColor: body.render.fillStyle,
        body,
      }
      Matter.World.add(ENGINE.world, body)
    }
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
    if (payload.by === this.peerId) {
      return
    }
    this.previouslyLockedByMe.delete(payload.block)
    this.lockedByOthers.add(payload.block)
    this.blocks[payload.block].body.render.fillStyle = '#e2e8f0'
  }

  onUnlockBlock(payload) {
    if (payload.by === this.peerId) {
      return
    }
    this.lockedByOthers.delete(payload.block)
    this.blocks[payload.block].body.render.fillStyle =
      this.blocks[payload.block].originalColor
  }

  onAfterUpdate() {
    const now = Date.now()
    if (now - this.lastSent < 10) {
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
    if (payload.by === this.peerId) {
      return
    }
    for (const change of payload.changes) {
      this.blocks[change.label].target = { x: change.x, y: change.y }
    }
  }
}
