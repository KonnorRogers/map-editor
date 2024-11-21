require "app/features/camera.rb"
require "app/tilesheets/loader.rb"
require "app/json.rb"

class MapEditor
  attr :mode, :hovered_tile, :selected_tile, :spritesheet_rect

  TILE_SIZE = 16
  EDITOR_TILE_SCALE = 2

  def initialize
    # @type [:add, :select, :remove]
    @mode = :add

    @nodesets_file = ""

    @water_spritesheet = Tilesheets::Loader.load_tiles(
      name: "water",
      path: "sprites/sproutlands/tilesets/water.png"
    )

    @grass_spritesheet = Tilesheets::Loader.load_tiles(
      name: "grass",
      path: "sprites/sproutlands/tilesets/grass.png"
    )

    @dirt_spritesheet = Tilesheets::Loader.load_tiles(
      name: "dirt",
      path: "sprites/sproutlands/tilesets/tilled_dirt_wide.png"
    )

    @nature_spritesheet = Tilesheets::Loader.load_tiles(
      name: "objects",
      path: "sprites/sproutlands/objects/basic_grass_biome_things.png"
    )

    @spritesheets = [
      @water_spritesheet,
      @grass_spritesheet,
      @dirt_spritesheet,
      @nature_spritesheet,
    ]

    @nodesets = [
    ]

    if @nodesets.length < 1
      create_nodeset
    end

    max_h = @spritesheets.max_by { |spritesheet| spritesheet.h }.h * EDITOR_TILE_SCALE
    max_w = @spritesheets.max_by { |spritesheet| spritesheet.w }.w * EDITOR_TILE_SCALE

    @spritesheets.each do |spritesheet|
      spritesheet.type = :spritesheet
      spritesheet.h = max_h
      spritesheet.w = max_w
    end

    @nodesets.each do |nodeset|
      nodeset.type = :nodeset
      # nodeset.h = Camera::SCREEN_HEIGHT.idiv(4)
      # nodeset.w = Camera::SCREEN_WIDTH.idiv(4)
    end

    @selected_spritesheet_index = 0
    @selected_nodeset_index = 0
  end

  def tick(args)
    load_tiles(args) if args.state.tick_count <= 0
    render_current_spritesheet(args) # if args.state.tick_count <= 0
    render_current_nodeset(args)
    calc(args)
    render(args)
    switch_mode(args)
  end

  def calc(args)
    inputs = args.inputs
    mouse = inputs.mouse

    state = args.state

    instructions = [
      "r to refresh.",
      "s to select.",
      "x to remove.",
      "a to add.",
      "t to change spritesheet",
      "mode: '#{@mode}'"
    ]

    instructions.each_with_index do |text, index|
      hash = {
        x: 10,
        y: 80.from_top,
        text: text
      }

      if index > 0
        prev_instruction = instructions[index - 1]
        _, prev_height = $gtk.calcstringbox(prev_instruction.text)
        hash[:y] = prev_instruction.y - prev_height
      end

      instructions[index] = hash
    end

    args.outputs.labels << instructions

    world_mouse = Camera.to_world_space state.camera, inputs.mouse

    if mouse.intersect_rect? @current_spritesheet
      tiles = @current_spritesheet.tiles.map do |current_tile|
        current_tile.merge({
          x: current_tile.x + @current_spritesheet.x,
          y: current_tile.y + @current_spritesheet.y,
          w: current_tile.w,
          h: current_tile.h
        })
      end

      tile = tiles.find { |tile| mouse.intersect_rect?(tile) }

      if tile
        @hovered_tile = tile
      else
        @hovered_tile = nil
      end
    else
      @hovered_tile = nil
    end

    if mouse.click && @hovered_tile
      @selected_tile = @hovered_tile.merge({
        w: @hovered_tile.w.idiv(EDITOR_TILE_SCALE),
        h: @hovered_tile.h.idiv(EDITOR_TILE_SCALE),
      })
    end

    @mouse_world_rect = nil
    if @selected_tile
      tile_width = @selected_tile.w
      tile_height = @selected_tile.h

      ifloor_x = world_mouse.x.ifloor(tile_width)
      ifloor_y = world_mouse.y.ifloor(tile_height)
      @mouse_world_rect = { x: ifloor_x,
                            y: ifloor_y,
                            w: tile_width,
                            h: tile_height }

      args.outputs.debug << "y: #{@mouse_world_rect.y}, x: #{@mouse_world_rect.x}"

      @selected_tile.x = @mouse_world_rect.x
      @selected_tile.y = @mouse_world_rect.y
    end

    if @mode == :remove && (mouse.click || (mouse.held && mouse.moved))
      args.state.tiles.reject! { |t| t.intersect_rect? @mouse_world_rect }
      save_tiles(args)
    elsif @mode == :select
      handle_box_select(args)
    elsif @selected_tile && (mouse.click || (mouse.held && mouse.moved)) # && !mouse.intersect_rect?(@current_spritesheet)
      if @mode == :add
        args.state.tiles.reject! { |t| t.intersect_rect? @selected_tile }
        args.state.tiles << @selected_tile.copy
      else
        args.state.tiles.reject! { |t| t.intersect_rect? @selected_tile }
      end
      save_tiles(args)
    end
  end

  def switch_mode(args)
    args.outputs.debug << "#{@selected_spritesheet_index}"

    if args.state.text_fields.any? { |input| input.focussed? }
      return
    end

    if args.inputs.keyboard.key_down.t
      @selected_spritesheet_index += 1

      if @selected_spritesheet_index > @spritesheets.length - 1
        @selected_spritesheet_index = 0
      end
    end

    if args.inputs.keyboard.key_down.n
      @selected_nodeset_index += 1

      if @selected_nodeset_index > @nodesets.length
        @selected_nodeset_index = 0
      end
    end

    if args.inputs.keyboard.x
      @mode = :remove
      @selected_tile = nil
    end

    if args.inputs.keyboard.s
      @mode = :select
      @selected_tile = nil
    end

    if args.inputs.keyboard.a
      @mode = :add
    end

    if args.inputs.mouse.click && @hovered_tile
      @mode = :add
    end
  end

  def render(args)
    outputs = args.outputs
    state = args.state

    # Render actual spritesheet
    sprites = [
    ]

    scene_sprites = []

    if @hovered_tile
      sprites << @hovered_tile.merge({ x: @hovered_tile.x,
                           y: @hovered_tile.y,
                           w: @hovered_tile.w,
                           h: @hovered_tile.h,
                           path: :pixel,
                           r: 255, g: 0, b: 0, a: 128 })
    end

    if @mode == :remove
      hovered_tile = args.state.tiles.find { |t| t.intersect_rect?(@mouse_world_rect) }

      if hovered_tile
        scene_sprites << (Camera.to_screen_space(state.camera, hovered_tile)).merge(path: :pixel, r: 255, g: 0, b: 0, a: 64)
      end
    end

    if @selected_tile
      scene_sprites << (Camera.to_screen_space(state.camera, @selected_tile))
      scene_sprites << (Camera.to_screen_space(state.camera, @selected_tile)).merge(path: :pixel, r: 0, g: 255, b: 255, a: 64)
    end

    outputs.sprites << sprites
    outputs[:scene].sprites << scene_sprites
  end

  def handle_box_select(args)
    reset = proc {
      @start_y = nil
      @start_x = nil
      @end_y = nil
      @end_x = nil
      @select_rect = nil
    }

    if @mode != :select
      reset.call
      return
    end

    mouse = args.inputs.mouse

    if args.inputs.keyboard.key_down.backspace || args.inputs.keyboard.key_down.delete || args.inputs.keyboard.key_down.x
      remove_tiles(args)
      save_tiles(args)
      reset.call
    end

    if mouse.click
      fill_tiles(args)
      save_tiles(args)
      reset.call
    end

    if (mouse.click || (mouse.held && mouse.moved))
      if @start_y.nil? && @start_x.nil?
        @start_y = args.inputs.mouse.y
        @start_x = args.inputs.mouse.x
      end

      @end_y = args.inputs.mouse.y
      @end_x = args.inputs.mouse.x
    end

    # Make sure we have something to render.
    if !(@start_y && @start_x && @end_x && @end_y)
      return
    end

    h = 0
    w = 0
    x = 0
    y = 0
    if @start_y > @end_y
      y = @end_y
      h = @start_y - @end_y
    else
      y = @start_y
      h = @end_y - @start_y
    end

    if @start_x > @end_x
      x = @end_x
      w = @start_x - @end_x
    else
      x = @start_x
      w = @end_x - @start_x
    end

    frame_index = 0.frame_index(
      start_at: 0,
      frame_count: 2,
      repeat: true,
      hold_for: 40,
    )

    alpha = 0
    if frame_index == 0
      alpha = 50
    else
      alpha = 150
    end


    @select_rect = {
      h: h,
      w: w,
      x: x,
      y: y,
    }

    args.outputs.borders << @select_rect.merge({
      r: 0,
      g: 0,
      b: 0,
      a: alpha,
      primitive_marker: :border
    })
  end

  def select_rect_to_tiles(args, tile_width: TILE_SIZE, tile_height: TILE_SIZE)
    select_rect = Camera.to_world_space(args.state.camera, @select_rect)
    select_rect.x = select_rect.x.ifloor(tile_width)
    select_rect.y = select_rect.y.ifloor(tile_height)

    select_rect
  end

  def remove_tiles(args, select_rect = nil)
    selection = select_rect || select_rect_to_tiles(args)
    args.state.tiles.reject! { |t| t.intersect_rect? selection }
  end

  def fill_tiles(args)
    return if @select_rect.nil?
    return if @selected_tile.nil?

    select_rect = select_rect_to_tiles(args)
    columns = select_rect.w.idiv(@selected_tile.w).floor
    rows = select_rect.h.idiv(@selected_tile.h).floor

    remove_tiles(args, select_rect)

    columns.times do |col|
      rows.times do |row|
        args.state.tiles << @selected_tile.merge({
          x: select_rect.x + (col * @selected_tile.w),
          y: select_rect.y + (row * @selected_tile.h),
          w: @selected_tile.w,
          h: @selected_tile.h
        })
      end
    end
  end

  def save_tiles(args)
    contents = JSON.to_json({
      tiles: args.state.tiles.uniq
    })
    $gtk.write_file("data/tiles.json", contents)
  end

  def load_tiles(args)
    return if args.state.tiles

    args.state.tiles = []

    begin
      json = $gtk.parse_json_file("data/tiles.json")
      tiles = json["tiles"].map do |tile|
        new_tile = {}
        tile.keys.each do |k|
          new_tile[k.to_sym] = tile[k]
        end
        new_tile
      end
      args.state.tiles = tiles
    rescue => e
    end
  end

  def render_current_spritesheet(args)
    @spritesheet_offset_x = 20
    @spritesheet_offset_y = 20

    @current_spritesheet = @spritesheets[@selected_spritesheet_index]
    @current_spritesheet = @current_spritesheet.merge({ x: @spritesheet_offset_x.from_right - @current_spritesheet.w, y: @spritesheet_offset_y })

    prev_tile = {
      x: 0,
      y: 0,
      w: 0,
      h: 0,
    }
    h = 0
    count = 0

    @current_spritesheet.tiles.each do |tile|
      if (count % @current_spritesheet.columns) == 0
        h = (count.idiv(@current_spritesheet.columns)) * (tile.source_h * EDITOR_TILE_SCALE)

        prev_tile = {
          x: 0,
          y: h,
          w: 0,
          h: 0,
        }
      end

      count += 1

      tile.x = prev_tile.x + prev_tile.w
      tile.y = prev_tile.y
      tile.w = tile.source_w * EDITOR_TILE_SCALE
      tile.h = tile.source_h  * EDITOR_TILE_SCALE

      prev_tile = tile
    end

    render_sheet(@current_spritesheet, args)
  end

  def render_sheet(sheet, args)
    # Make a background for borders.
    sheet_border = { x: sheet.x - 2, y: sheet.y - 2, w: sheet.w + 4, h: sheet.h + 4, r: 0, g: 0, b: 0, a: 255, path: :pixel }

    sheet_id = "__sheet__#{sheet.id}"
    args.outputs[sheet_id].w = sheet.w
    args.outputs[sheet_id].h = sheet.h

    background_tiles = []

    count = 0
    sheet.h.idiv(TILE_SIZE * EDITOR_TILE_SCALE).times do |row|
      sheet.w.idiv(TILE_SIZE * EDITOR_TILE_SCALE).times do |column|
        count += 1
        x = column * TILE_SIZE * EDITOR_TILE_SCALE
        y = row * TILE_SIZE * EDITOR_TILE_SCALE

        background = (count % 2).to_i == 0 ? { r: 230, g: 230, b: 230 } : { r: 180, g: 180, b: 180 }

        background_tiles << {
          x: x,
          y: y,
          h: TILE_SIZE * EDITOR_TILE_SCALE,
          w: TILE_SIZE * EDITOR_TILE_SCALE,
          path: :pixel,
        }.merge!(background)
      end
    end

    _label_width, label_height = $gtk.calcstringbox(sheet.name)

    label = {
      x: sheet_border.x,
      y: sheet_border.y + sheet_border.h + label_height + 8,
      text: sheet.name
    }

    # Always make background_tiles before sheet tiles.
    args.outputs[sheet_id].sprites << [background_tiles, sheet.tiles]
    args.outputs.sprites << [sheet_border, sheet.merge({ path: sheet_id })]
    args.outputs.labels << [label]
  end

  def render_current_nodeset(args)
    @current_nodeset = @nodesets[@selected_nodeset_index]
    args.outputs.debug << "#{@current_nodeset}"
    render_sheet(@current_nodeset, args)
  end

  def create_nodeset
    @nodesets << {
      name: "nodeset__#{@nodesets.length + 1}",
      id: "nodeset__#{@nodesets.length + 1}",
      type: :nodeset,
      h: 200,
      w: 320 + 32,
      x: 20,
      y: 20,
      tiles: []
    }

    save_nodesets
  end

  def save_nodesets
  end

  def delete_nodeset
  end
end
