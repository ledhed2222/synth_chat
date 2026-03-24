import Matter from 'matter-js'
import { Socket } from 'phoenix'
import { ViewHook } from 'phoenix_live_view'

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
    this.connect()

    const render = Matter.Render.create({
      engine: ENGINE,
      element: this.el,
      options: RENDER_OPTIONS,
    })
    Matter.Render.run(render)
    Matter.Runner.run(RUNNER, ENGINE)

    Matter.World.add(ENGINE.world, WALLS)

    const mouse = Matter.Mouse.create(render.canvas)
    const mouseConstraint = Matter.MouseConstraint.create(ENGINE, { mouse })
    Matter.World.add(ENGINE.world, mouseConstraint)

    // Create named blocks and keep references by label
    this.blocks = {}
    for (const block of BLOCKS) {
      const body = createBlock(block)
      this.blocks[block.label] = {
        originalColor: body.render.fillStyle,
        body,
      }
      Matter.World.add(ENGINE.world, body)
    }

    // Lock a block when a user starts dragging it until they have finished
    // and prevent locked blocks from being moved
    this.lockedByOthers = new Set()
    this.lockedByMe = new Set()

    Matter.Events.on(mouseConstraint, 'startdrag', (event) => {
      if (this.lockedByOthers.has(event.body.label)) {
        mouseConstraint.constraint.bodyB = null
        mouseConstraint.constraint.pointB = null
        mouseConstraint.body = null
        return
      }
      this.lockedByMe.add(event.body.label)
      this.channel.push('lock-block', {
        block: event.body.label,
        by: this.peerId,
      })
    })

    Matter.Events.on(mouseConstraint, 'enddrag', (event) => {
      if (this.lockedByOthers.has(event.body.label)) {
        mouseConstraint.constraint.bodyB = null
        mouseConstraint.constraint.pointB = null
        mouseConstraint.body = null
        return
      }
      Matter.Body.setVelocity(event.body, {
        x: 0,
        y: 0,
      })
      Matter.Body.setAngularVelocity(event.body, 0)
      this.lockedByMe.delete(event.body.label)
      this.channel.push('unlock-block', {
        block: event.body.label,
        by: this.peerId,
      })
    })

    this.channel.on('lock-block', (payload) => {
      if (payload.by === this.peerId) {
        return
      }
      this.lockedByOthers.add(payload.block)
      this.blocks[payload.block].body.render.fillStyle = 'red'
    })

    this.channel.on('unlock-block', (payload) => {
      if (payload.by === this.peerId) {
        return
      }
      this.lockedByOthers.delete(payload.block)
      this.blocks[payload.block].body.render.fillStyle =
        this.blocks[payload.block].originalColor
    })
    // END block locking

    // Send positions to Elixir on each physics tick, throttled to ~10Hz
    // TODO what i really want to do is track the motion of a block that was
    // moved by this user until it stops?
    let lastSent = 0
    Matter.Events.on(ENGINE, 'afterUpdate', () => {
      const now = Date.now()
      if (now - lastSent < 10) {
        return
      }
      lastSent = now

      // TODO there is a better way to do all of this
      let anyChangesByMe = false
      const payload = {
        by: this.peerId,
        changes: [],
      }
      for (const block of Object.entries(this.blocks)) {
        const [label, { body }] = block
        if (!this.lockedByMe.has(label)) {
          continue
        }
        anyChangesByMe = true
        payload.changes.push({
          x: body.position.x,
          y: body.position.y,
          xNormalized: normalize(body.position.x, WIDTH),
          yNormalized: normalize(body.position.y, HEIGHT),
          label,
        })
      }
      if (anyChangesByMe) {
        this.channel.push('block-update', payload)
      }
    })

    this.channel.on('block-update', (payload) => {
      if (payload.by === this.peerId) {
        return
      }
      console.log(payload)
      for (const change of payload.changes) {
        Matter.Body.setPosition(this.blocks[change.label].body, {
          x: change.x,
          y: change.y,
        })
      }
    })
  }

  connect() {
    this.peerId = window.uuid
    const socket = new Socket('/socket', {})
    socket.connect()
    this.channel = socket.channel('physics:lobby', {})
    this.channel
      .join()
      .receive('ok', (response) => {
        console.log('Joined physics room successfully', response)
      })
      .receive('error', (response) => {
        console.log('Unable to join physics room', response)
      })
  }
}
