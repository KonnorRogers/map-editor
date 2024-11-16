require "app/tilesheets/water.rb"
require "app/features/camera.rb"
require "app/features/map_editor.rb"

class DebugScene
  def initialize
    @map_editor = MapEditor.new
  end

  def calc_camera(args)
    state = args.state
    state.world_size ||= 1280

    if !state.camera
      state.camera = {
        x: 0,
        y: 0,
        target_x: 0,
        target_y: 0,
        target_scale: 2,
        scale: 1
      }
    end

    ease = 0.1
    state.camera.scale += (state.camera.target_scale - state.camera.scale) * ease
    # state.camera.target_x = player.x
    # state.camera.target_y = player.y

    state.camera.x += (state.camera.target_x - state.camera.x) * ease
    state.camera.y += (state.camera.target_y - state.camera.y) * ease
  end

  def tick(args)
    args.state.terrain ||= []
    calc_camera(args)
    args.outputs.sprites << { **Camera.viewport, path: :scene }

    args.outputs[:scene].w = 1500
    args.outputs[:scene].h = 1500
    @map_editor.tick(args)
    # tile_size = 16

    # height = tile_size * 32
    # width = tile_size * 32

    # if !args.state.grid
    #   grid = []

    #   offset = 200

    #   height.idiv(tile_size).times do |x|
    #     grid[x] = []

    #     width.idiv(tile_size).times do |y|
    #       grid[x][y] = Water.new(tile_size: tile_size, x: x * tile_size + offset, y: y * tile_size + offset)
    #     end
    #   end

    #   args.state.grid = grid
    # end

    # sprites = []

    # args.state.grid.each do |ary|
    #   ary.each { |sprite| sprites << sprite.animate }
    # end

    # args.outputs.sprites << sprites
  end
end
