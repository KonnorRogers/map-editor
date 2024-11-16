require "app/features/camera.rb"
require "app/tilesheets/water.rb"

class MapEditor
  attr :mode, :hovered_tile, :selected_tile, :tilesheet_rect

  TILE_SIZE = 16

  def initialize
    # @attr {"add" | "select" | "remove"}
    @mode = :add
    @tiles = [
      [Tilesheets::Water.new(tile_size: TILE_SIZE)],
      [],
      [],
      [],
      [],
      [],
      [],
      [],
    ]

    @tilesheet_height = @tiles.length * TILE_SIZE
    @tilesheet_width = @tiles.max_by { |ary| ary.length }.length * TILE_SIZE
    @tilesheet_rect = { x: 0, y: 0, w: @tilesheet_width, h: @tilesheet_height }
  end

  def tick(args)
    generate_tilesheet(args)
    calc(args)
    render(args)
  end

  def calc(args)
    tile_size = 16

    inputs = args.inputs
    mouse = inputs.mouse

    state = args.state
    camera = state.camera

    args.outputs.debug << "
`s` to select.
`x` to remove.
`a` to add.
    "

    if inputs.keyboard.x
      @mode = @modes.remove
    end

    if inputs.keyboard.s
      @mode = @modes.select
    end

    if inputs.keyboard.a
      @mode = @modes.add
    end

    args.outputs.debug << "#{@mode}"

    if mouse.intersect_rect? @tilesheet_rect
      x_ordinal = mouse.x.idiv(tile_size)
      y_ordinal = mouse.y.idiv(tile_size)

      rows = @tiles.length

      row = rows - y_ordinal - 1
      column = x_ordinal

      tile = @tiles[row][column]

      if tile
        @hovered_tile = { x: mouse.x.idiv(tile_size) * tile_size,
                          y: mouse.y.idiv(tile_size) * tile_size,
                          row: rows - y_ordinal - 1,
                          col: x_ordinal,
                          path: tile.path,
                          w: tile_size,
                          h: tile_size }

      else
        @hovered_tile = nil
      end
    else
      @hovered_tile = nil
    end

    if mouse.click && @hovered_tile
      @selected_tile = @hovered_tile
    end

    world_mouse = Camera.to_world_space state.camera, inputs.mouse
    ifloor_x = world_mouse.x.ifloor(tile_size)
    ifloor_y = world_mouse.y.ifloor(tile_size)

    @mouse_world_rect =  { x: ifloor_x,
                           y: ifloor_y,
                           w: tile_size,
                           h: tile_size }

    if @selected_tile
      ifloor_x = world_mouse.x.ifloor(tile_size)
      ifloor_y = world_mouse.y.ifloor(tile_size)
      @selected_tile.x = @mouse_world_rect.x
      @selected_tile.y = @mouse_world_rect.y
    end

    if @mode == :remove && (mouse.click || (mouse.held && mouse.moved))
      # state.terrain.reject! { |t| t.intersect_rect? @mouse_world_rect }
      # save_terrain args
    elsif @selected_tile && (mouse.click || (mouse.held && mouse.moved))
      if @mode == :add
        # state.terrain.reject! { |t| t.intersect_rect? @selected_tile }
        # state.terrain << @selected_tile.copy
      else
        # state.terrain.reject! { |t| t.intersect_rect? @selected_tile }
      end
      # save_terrain args
    end
  end

  def render(args)
    outputs = args.outputs
    state = args.state

    outputs.sprites << { x: 0, y: 0, w: @tilesheet_width, h: @tilesheet_height, path: :tilesheet }

    if @hovered_tile
      outputs.sprites << { x: @hovered_tile.x,
                           y: @hovered_tile.y,
                           w: TILE_SIZE,
                           h: TILE_SIZE,
                           path: :pixel,
                           r: 255, g: 0, b: 0, a: 128 }
    end

    if @selected_tile
      if @mode == :remove
        outputs[:scene].sprites << (Camera.to_screen_space state.camera, @selected_tile).merge(path: :pixel, r: 255, g: 0, b: 0, a: 64)
      elsif @selected_tile
        outputs[:scene].sprites << (Camera.to_screen_space state.camera, @selected_tile)
        outputs[:scene].sprites << (Camera.to_screen_space state.camera, @selected_tile).merge(path: :pixel, r: 0, g: 255, b: 255, a: 64)
      end
    end
  end

  def generate_tilesheet(args)
    return if args.state.tick_count > 0

    @tiles.each_with_index do |ary, row|
      ary.each_with_index do |tile, column|
        # Gaps dont apply to first items.
        row_gap = row > 0 ? ROW_GAP : 0
        column_gap = column > 0 ? COLUMN_GAP : 0

        tile.tile_size = TILE_SIZE
        tile.y = @tilesheet_height - TILE_SIZE - ((column * TILE_SIZE) + column_gap)
        tile.x = (row * TILE_SIZE) + row_gap
        tile.w = TILE_SIZE
        tile.h = TILE_SIZE
      end
    end

    outputs = args.outputs
    outputs[:tilesheet].w = @tilesheet_width
    outputs[:tilesheet].h = @tilesheet_height
    outputs[:tilesheet].sprites << { x: 0, y: 0, w: @tilesheet_width, h: @tilesheet_height, path: :pixel, r: 0, g: 0, b: 0 }
    outputs[:tilesheet].sprites << @tiles
  end

  # def save_terrain(args)
  #   contents = args.state.terrain.uniq.map do |terrain_element|
  #     "#{terrain_element.x.to_i},#{terrain_element.y.to_i},#{terrain_element.w.to_i},#{terrain_element.h.to_i},#{terrain_element.path}"
  #   end
  #   File.write "data/terrain.txt", contents.join("\n")
  # end

  # def load_terrain(args)
  #   args.state.terrain = []
  #   contents = File.read("data/terrain.txt")
  #   return if !contents
  #   args.state.terrain = contents.lines.map do |line|
  #     l = line.strip
  #     if l.empty?
  #       nil
  #     else
  #       x, y, w, h, path = l.split ","
  #       { x: x.to_f, y: y.to_f, w: w.to_f, h: h.to_f, path: path }
  #     end
  #   end.compact.to_a.uniq
  # end
end
