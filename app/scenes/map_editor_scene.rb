require "app/features/camera.rb"
require "app/features/map_editor.rb"

class MapEditorScene
  def initialize
    @map_editor = MapEditor.new
  end

  def tick(args)
    @map_editor.load_tiles(args)

    calc_camera(args)
    move_camera(args)

    args.outputs.sprites << { **Camera.viewport, path: :scene }

    args.outputs[:scene].w = 1500
    args.outputs[:scene].h = 1500

    state = args.state
    tiles_to_render = Camera.find_all_intersect_viewport(state.camera, state.tiles)
    args.outputs[:scene].sprites << tiles_to_render.map do |m|
      Camera.to_screen_space(state.camera, m)
    end

    @map_editor.tick(args)

    # Starting map editor box.
    start_scale = args.state.start_camera.scale
    args.outputs[:scene].borders << Camera.to_screen_space(state.camera, {
      x: (Camera::SCREEN_WIDTH / -2) / start_scale,
      y: (Camera::SCREEN_HEIGHT / -2) / start_scale,
      w: Camera::SCREEN_WIDTH / start_scale,
      h: Camera::SCREEN_HEIGHT / start_scale,
      r: 255,
      g: 0,
      b: 0,
      a: 255,
      primitive: :border
    })
  end

  def move_camera(args)
    inputs = args.inputs

    if args.state.text_fields.any? { |input| input.focussed? }
      return
    end

    speed = 3 + (3 / args.state.camera.scale)

    # Movement
    if inputs.keyboard.left_arrow
      args.state.camera.target_x -= speed
    elsif inputs.keyboard.right_arrow
      args.state.camera.target_x += speed
    end

    if inputs.keyboard.down_arrow
      args.state.camera.target_y -= speed
    elsif inputs.keyboard.up_arrow
      args.state.camera.target_y += speed
    end

    # Zoom
    state = args.state
    if args.inputs.keyboard.key_down.equal_sign || args.inputs.keyboard.key_down.plus
      state.camera.target_scale += 0.25
    elsif args.inputs.keyboard.key_down.minus
      state.camera.target_scale -= 0.25
      state.camera.target_scale = 0.25 if state.camera.target_scale < 0.25
    elsif args.inputs.keyboard.zero
      state.camera.target_scale = 1
    end
  end

  def calc_camera(args)
    state = args.state

    if !state.camera
      state.camera = {
        x: 0,
        y: 0,
        target_x: 0,
        target_y: 0,
        target_scale: 2,
        scale: 2
      }

      args.state.start_camera = { scale: state.camera.scale }
    end

    ease = 0.1
    state.camera.scale += (state.camera.target_scale - state.camera.scale) * ease

    state.camera.x += (state.camera.target_x - state.camera.x) * ease
    state.camera.y += (state.camera.target_y - state.camera.y) * ease
  end
end
