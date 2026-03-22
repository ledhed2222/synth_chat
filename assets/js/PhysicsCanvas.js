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
  y: 0.1,
}
const RUNNER = Matter.Runner.create()

export default class PhysicsCanvas extends ViewHook {
  mounted() {
    const render = Matter.Render.create({
      engine: ENGINE,
      element: this.el,
      options: RENDER_OPTIONS,
    })
    Matter.Render.run(render)

    Matter.Runner.run(RUNNER, ENGINE)

    const mouse = Matter.Mouse.create(render.canvas)
    const mouseConstraint = Matter.MouseConstraint.create(ENGINE, { mouse })
    Matter.World.add(ENGINE.world, mouseConstraint)
    Matter.Events.on(mouseConstraint, 'mousedown', (event) => {
      const body = Matter.Bodies.rectangle(
        event.mouse.position.x,
        event.mouse.position.y,
        50,
        50,
        { fillStyle: 'white' },
      )
      this.pushEvent('client-audio-update', {
        pos_x: body.position.x,
        pos_y: body.position.y,
      })
      Matter.World.add(ENGINE.world, body)
    })
  }
}
