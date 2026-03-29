import Matter from 'matter-js'

const _WIDTH = 800
const _HEIGHT = 800

const RENDER_OPTIONS = {
  width: _WIDTH,
  height: _HEIGHT,
  wireframes: false,
}

const ENGINE = Matter.Engine.create({
  enableSleeping: true,
  positionIterations: 10,
  velocityIterations: 15,
})
ENGINE.gravity = { x: 0, y: 0, scale: 0 }

const RUNNER = Matter.Runner.create()

const _WALL_THICKNESS = 500
const WALLS = [
  // floor
  Matter.Bodies.rectangle(
    _WIDTH / 2,
    _HEIGHT + _WALL_THICKNESS / 2,
    _WIDTH,
    _WALL_THICKNESS,
    { isStatic: true },
  ),
  // ceiling
  Matter.Bodies.rectangle(
    _WIDTH / 2,
    -_WALL_THICKNESS / 2,
    _WIDTH,
    _WALL_THICKNESS,
    { isStatic: true },
  ),
  // left
  Matter.Bodies.rectangle(
    -_WALL_THICKNESS / 2,
    _HEIGHT / 2,
    _WALL_THICKNESS,
    _HEIGHT,
    { isStatic: true },
  ),
  // right
  Matter.Bodies.rectangle(
    _WIDTH + _WALL_THICKNESS / 2,
    _HEIGHT / 2,
    _WALL_THICKNESS,
    _HEIGHT,
    { isStatic: true },
  ),
]

function _normalize(value, max) {
  return Math.min(1, Math.max(0, value / max))
}

function normalizeWidth(value) {
  return _normalize(value, _WIDTH)
}

function normalizeHeight(value) {
  return _normalize(value, _HEIGHT)
}

function denormalizeWidth(value) {
  return value * _WIDTH
}

function denormalizeHeight(value) {
  return value * _HEIGHT
}

function createBlock({ label, x, y, color }) {
  return Matter.Bodies.rectangle(x, y, 50, 50, {
    label,
    render: { fillStyle: color },
    inertia: Infinity,
    frictionAir: 0.05,
    restitution: 0.5,
  })
}

export default {
  RENDER_OPTIONS,
  ENGINE,
  RUNNER,
  WALLS,
  normalizeWidth,
  normalizeHeight,
  denormalizeWidth,
  denormalizeHeight,
  createBlock,
}
