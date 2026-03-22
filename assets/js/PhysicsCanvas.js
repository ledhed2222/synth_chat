import Matter from 'matter-js'
import { ViewHook } from 'phoenix_live_view'

const WIDTH = 800
const HEIGHT = 800
const RENDER_OPTIONS = {
  width: WIDTH,
  height: HEIGHT,
  wireframes: false,
}
const ENGINE = Matter.Engine.create()
ENGINE.world.gravity = {
  x: 0,
  y: 0,
}
const RUNNER = Matter.Runner.create()

const BLOCKS = [
  { label: 'frequency', x: WIDTH / 2, y: 100, color: '#d79921' },
  { label: 'filterCutoff', x: WIDTH / 2 - 100, y: 100, color: '#ff80ed' },
]

// Normalize a position value to 0.0–1.0 within the canvas bounds
function normalize(value, max) {
  return Math.min(1, Math.max(0, value / max))
}

function createBlock({ label, x, y, color }) {
  return Matter.Bodies.rectangle(x, y, 50, 50, {
    label,
    render: { fillStyle: color },
  })
}

export default class PhysicsCanvas extends ViewHook {
  mounted() {
    const render = Matter.Render.create({
      engine: ENGINE,
      element: this.el,
      options: RENDER_OPTIONS,
    })
    Matter.Render.run(render)
    Matter.Runner.run(RUNNER, ENGINE)

    const thickness = 50
    const walls = [
      // floor
      Matter.Bodies.rectangle(
        WIDTH / 2,
        HEIGHT + thickness / 2,
        WIDTH,
        thickness,
        { isStatic: true },
      ),
      // left
      Matter.Bodies.rectangle(-thickness / 2, HEIGHT / 2, thickness, HEIGHT, {
        isStatic: true,
      }),
      // right
      Matter.Bodies.rectangle(
        WIDTH + thickness / 2,
        HEIGHT / 2,
        thickness,
        HEIGHT,
        { isStatic: true },
      ),
    ]
    Matter.World.add(ENGINE.world, walls)

    const mouse = Matter.Mouse.create(render.canvas)
    const mouseConstraint = Matter.MouseConstraint.create(ENGINE, { mouse })
    Matter.World.add(ENGINE.world, mouseConstraint)

    // Create named blocks and keep references by label
    this.blocks = {}
    BLOCKS.forEach((def) => {
      const body = createBlock(def)
      this.blocks[def.label] = body
      Matter.World.add(ENGINE.world, body)
    })

    // Send positions to Elixir on each physics tick, throttled to ~10Hz
    let lastSent = 0
    Matter.Events.on(ENGINE, 'afterUpdate', () => {
      const now = Date.now()
      if (now - lastSent < 100) {
        return
      }
      lastSent = now

      const payload = {}
      Object.entries(this.blocks).forEach(([label, body]) => {
        payload[label] = {
          x: normalize(body.position.x, WIDTH),
          y: normalize(body.position.y, HEIGHT),
        }
      })
      this.pushEvent('client-audio-update', payload)
    })
  }
}
