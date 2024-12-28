require "app/hash_methods.rb"
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

    # @type [Boolean]
    @show_grid = false
    @grid_border_size = 0

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

    @nodesets = load_nodesets
    # @nodesets = []

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
    end

    @selected_spritesheet_index = 0
    @selected_nodeset_index = 0
  end

  def tick(args)
    args.state.buttons ||= []
    render_screen_boxes(args)
    load_tiles(args) if args.state.tick_count <= 0
    render_current_spritesheet(args) # if args.state.tick_count <= 0
    render_current_nodeset(args)
    calc(args)
    render(args)
    handle_nodeset_buttons(args)
    handle_spritesheet_buttons(args)
    switch_mode(args)
  end

  def render_screen_boxes(args)
    grid_border_size = 1
    width = 1280
    height = 1280
    if Kernel.tick_count == 0
      args.outputs[:grid].w = width
      args.outputs[:grid].h = height
      args.outputs[:grid].background_color = [0, 0, 0, 0]
      @grid = []
      height.idiv(16).each do |x|
        width.idiv(16).each do |y|
          @grid << { line_type: :horizontal, x: x * TILE_SIZE, y: y * TILE_SIZE, w: TILE_SIZE, h: grid_border_size, r: 200, g: 200, b: 200, a: 255, primitive_marker: :sprite, path: :pixel }
          @grid << { line_type: :vertical, x: x * TILE_SIZE, y: y * TILE_SIZE, w: grid_border_size, h: TILE_SIZE, r: 200, g: 200, b: 200, a: 255, primitive_marker: :sprite, path: :pixel }
        end
      end
    end

    if !@show_grid
      # args.outputs[:grid].sprites.clear
      return
    end

    if args.state.camera && args.state.camera.scale != @current_scale
      @current_scale = args.state.camera.scale
      # if args.state.camera.scale <= 0.5
      #   args.outputs[:grid].sprites.clear
      #   return
      # end

      if args.state.camera.scale < 1
        border_size = (grid_border_size / args.state.camera.scale).ceil
      else
        border_size = grid_border_size
      end

      @grid_border_size = border_size

      @grid.each do |line|
        line.w = @grid_border_size if line[:line_type] == :vertical
        line.h = @grid_border_size if line[:line_type] == :horizontal
      end

      # Update the grid with new widths.
      args.outputs[:grid].sprites.clear
      args.outputs[:grid].sprites << @grid
    end

    args.state.grid_boxes ||= 10.flat_map do |x|
      10.map do |y|
        { x: (x - 5) * 1280, y: (y - 5) * 1280, w: 1280, h: 1280, path: :grid }
      end
    end

    args.outputs[:scene].sprites << args.state.grid_boxes.map do |rect|
      Camera.to_screen_space(args.state.camera, rect)
    end
  end

  def handle_nodeset_buttons(args)
    mouse = args.inputs.mouse
    return if !mouse.click

    if mouse.intersect_rect?(@add_nodeset_button)
      create_nodeset
    end

    if mouse.intersect_rect?(@previous_nodeset_button)
      previous_nodeset
    end

    if mouse.intersect_rect?(@next_nodeset_button)
      next_nodeset
    end
  end

  def handle_spritesheet_buttons(args)
    mouse = args.inputs.mouse
    return if !mouse.click

    # if mouse.intersect_rect?(@add_spritesheet_button)
    #   create_spritesheet
    # end

    if mouse.intersect_rect?(@previous_spritesheet_button)
      previous_spritesheet
    end

    if mouse.intersect_rect?(@next_spritesheet_button)
      next_spritesheet
    end
  end

  def calc(args)
    inputs = args.inputs
    mouse = inputs.mouse
    state = args.state

    tile_width = TILE_SIZE
    tile_height = TILE_SIZE

    if @selected_sprite
      # args.outputs.debug << "y: #{@mouse_world_rect.y}, x: #{@mouse_world_rect.x}"
      @selected_sprite.x = @mouse_world_rect.x
      @selected_sprite.y = @mouse_world_rect.y
    end

    world_mouse = Camera.to_world_space state.camera, inputs.mouse

    ifloor_x = world_mouse.x.ifloor(tile_width)
    ifloor_y = world_mouse.y.ifloor(tile_height)

    @mouse_world_rect = { x: ifloor_x,
                          y: ifloor_y,
                          w: tile_width,
                          h: tile_height }


    instructions = [
      "r to refresh.",
      "s to select.",
      "x to remove.",
      "a to add.",
      "t to change spritesheet",
      "mode: '#{@mode}'"
    ]

    instructions.each_with_index do |text, index|
      text_width, _ = $gtk.calcstringbox(text)
      hash = {
        x: 10.from_right - text_width,
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

      @hovered_sprite = tile
    else
      @hovered_sprite = nil
    end

    if @hovered_sprite
      # make a new sprite.
      selected_sprite = @hovered_sprite.merge({})

      if mouse.click
        @selected_node = nil

        if @selected_sprite && args.inputs.keyboard.shift
          @selected_sprite = combine_sprites(@selected_sprite, selected_sprite)
        else
          @selected_sprite = selected_sprite
        end

        @selected_sprite.merge!({
          w: @selected_sprite.source_w,
          h: @selected_sprite.source_h
        })
      elsif args.inputs.keyboard.shift && @selected_sprite && @current_spritesheet
        sprites = []
        sprite = combine_sprites(@selected_sprite, selected_sprite)
        sprite = {
          w: sprite.source_w * EDITOR_TILE_SCALE,
          h: sprite.source_h * EDITOR_TILE_SCALE,
          x: sprite.source_x * EDITOR_TILE_SCALE,
          y: sprite.source_y * EDITOR_TILE_SCALE,
          r: 200, g: 200, b: 200, a: 128,
          path: :pixel,
        }

        # sprite = sprite_to_nodeset_rect(mouse, sprite, @current_spritesheet)
        sprites << sprite
        sprites << create_borders(sprite, border_width: 2, color: { r: 100, b: 100, g: 100, a: 255 }).values

        sheet_id = "__sheet__#{@current_spritesheet.id}"

        args.outputs[sheet_id].sprites << sprites
      end
    end

    # Must come before "@mode" changes
    calc_nodes(args)

    if @mode == :remove && (mouse.click || (mouse.held && mouse.moved))
      @should_save = true
      intersecting_tiles = args.state.geometry.find_all_intersect_rect(@mouse_world_rect, args.state.tiles)
      intersecting_tiles.each { |t| args.state.tiles.delete(t) }
    elsif @mode == :select
      handle_box_select(args)
    # TODO: Change to "@selected_node"
    elsif @selected_node && (mouse.click || (mouse.held && mouse.moved)) && !mouse.intersect_rect?(@current_spritesheet)
      if @mode == :add
        @should_save = true
        intersecting_tiles = args.state.geometry.find_all_intersect_rect(@selected_node, args.state.tiles)
        intersecting_tiles.each { |t| args.state.tiles.delete(t) }
        args.state.tiles << @selected_node.copy
      end
    end

    # Purposely delay saving until `mouse.up` because other wise the editor lags a lot.
    if mouse.up && @should_save
      @should_save = false
      save_tiles(args)
    end
  end

  def switch_mode(args)
    # args.outputs.debug << "#{@selected_spritesheet_index}"

    if args.state.text_fields.any? { |input| input.focussed? }
      return
    end

    if args.inputs.keyboard.key_down.t
      @selected_spritesheet_index += 1

      if @selected_spritesheet_index > @spritesheets.length - 1
        @selected_spritesheet_index = 0
      end
      @selected_sprite = nil
    end

    if args.inputs.keyboard.key_down.n
      @selected_nodeset_index += 1

      if @selected_nodeset_index > @nodesets.length - 1
        @selected_nodeset_index = 0
      end
    end

    if args.inputs.keyboard.x
      @mode = :remove
      @selected_sprite = nil
      @selected_node = nil
    end

    if args.inputs.keyboard.s
      @mode = :select
      @selected_sprite = nil
      @selected_node = nil
    end

    if args.inputs.keyboard.a
      @mode = :add
    end

    if args.inputs.mouse.click && @hovered_sprite
      @mode = :add
    end

    if args.inputs.keyboard.key_down.g
      @show_grid = !@show_grid
    end

    if args.inputs.keyboard.key_down.escape
      @selected_sprite = nil
      @selected_node = nil
      @select_rect = nil
    end
  end

  def render(args)
    outputs = args.outputs
    state = args.state

    # Render actual spritesheet
    sprites = [
    ]

    scene_sprites = []

    if @hovered_sprite
      sprites << @hovered_sprite.merge({
                           path: :pixel,
                           r: 0, g: 0, b: 128, a: 64
                 })

      sprites << create_borders(@hovered_sprite, border_width: 2, color: { r: 0, b: 255, g: 0, a: 255 }).values
    end

    if @mode == :remove
      hovered_tile = args.state.tiles.find { |t| t.intersect_rect?(@mouse_world_rect) }

      if hovered_tile
        scene_sprites << (Camera.to_screen_space(state.camera, hovered_tile)).merge(path: :pixel, r: 255, g: 0, b: 0, a: 128)
      end
    end

    if @mode == :add && @selected_node
      hovered_tiles = args.state.tiles.select { |t| t.intersect_rect?(@selected_node) }

      if hovered_tiles.length > 0
        hovered_tiles.each do |hovered_tile|
          world_hovered_tile = (Camera.to_screen_space(state.camera, hovered_tile)).merge(path: :pixel, r: 255, g: 0, b: 0, a: 128)
          scene_sprites << world_hovered_tile
          scene_sprites << create_borders(world_hovered_tile, border_width: 2, color: { r: 255, g: 0, b: 0, a: 255 }).values
        end
      end
    end

    if @selected_sprite
      sheet_id = "__sheet__#{@current_nodeset.id}"

      if !args.inputs.mouse.intersect_rect?(@current_nodeset)
        scene_sprites << (Camera.to_screen_space(state.camera, @selected_sprite))
        scene_sprites << (Camera.to_screen_space(state.camera, @selected_sprite)).merge(path: :pixel, r: 255, g: 0, b: 0, a: 64)
      else
        sprite = sprite_to_nodeset_rect(args.inputs.mouse, @selected_sprite, @current_nodeset)
        outputs[sheet_id].sprites << sprite
        outputs[sheet_id].sprites << sprite.merge(path: :pixel, r: 0, g: 255, b: 0, a: 30)
        outputs[sheet_id].sprites << create_borders(sprite, border_width: 2, color: { r: 0, g: 100, b: 0, a: 255 }).values
      end

    end

    if @selected_node
      @selected_node.x = @mouse_world_rect.x
      @selected_node.y = @mouse_world_rect.y

      selected_node = (Camera.to_screen_space(state.camera, @selected_node))
      scene_sprites << selected_node
      selected_node_bg = selected_node.merge({ path: :pixel, r: 0, g: 255, b: 0, a: 20 })
      scene_sprites << create_borders(selected_node_bg, border_width: 2, color: {
        r: 0,
        g: 255,
        b: 0,
        a: 255,
      }).values
      scene_sprites << selected_node_bg
    end

    # args.outputs.debug << "nodeset tiles: #{@current_nodeset.tiles.length}"

    outputs.sprites << [sprites, args.state.buttons]
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
      b: 255,
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
    return if @selected_node.nil?

    select_rect = select_rect_to_tiles(args)
    columns = select_rect.w.idiv(@selected_node.w).floor
    rows = select_rect.h.idiv(@selected_node.h).floor

    remove_tiles(args, select_rect)

    columns.times do |col|
      rows.times do |row|
        args.state.tiles << @selected_node.merge({
          x: select_rect.x + (col * @selected_node.w),
          y: select_rect.y + (row * @selected_node.h),
          w: @selected_node.w,
          h: @selected_node.h
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
      tiles = json["tiles"].map { |tile| HashMethods.symbolize_keys(tile) }
      args.state.tiles = tiles
    rescue => e
    end
  end

  def load_nodesets
    nodesets = []
    begin
      json = $gtk.parse_json_file("data/nodesets.json")

      if json
        nodesets = json["nodesets"].map do |nodeset|
          nodeset = HashMethods.symbolize_keys(nodeset)
          nodeset[:tiles] = nodeset[:tiles].map { |tile| HashMethods.symbolize_keys(tile) }
          nodeset
        end
      end
    rescue => e
      puts e
      nodesets = []
    end

    nodesets
  end

  def save_nodesets
    $gtk.write_file("data/nodesets.json", JSON.to_json({ nodesets: @nodesets }))
  end

  def render_current_spritesheet(args)
    @spritesheet_offset_x = 20
    @spritesheet_offset_y = 20

    @current_spritesheet = @spritesheets[@selected_spritesheet_index]
    @current_spritesheet = @current_spritesheet.merge({ x: @spritesheet_offset_x, y: 80 })

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
      tile.h = tile.source_h * EDITOR_TILE_SCALE

      prev_tile = tile
    end

    render_sheet(@current_spritesheet, args)

    text = "<"
    @previous_spritesheet_button = create_button(args,
                id: :previous_spritesheet_button,
                text: text,
                background: { r: 220, g: 220, b: 220, a: 255 },
              )
    @previous_spritesheet_button = @previous_spritesheet_button.merge({
        id: :previous_spritesheet_button,
        x: @current_spritesheet.x,
        y: @current_spritesheet.y - @previous_spritesheet_button.h - 8,
        path: :previous_spritesheet_button
    })

    args.state.buttons << @previous_spritesheet_button

    text = ">"
    @next_spritesheet_button = create_button(args,
                id: :next_spritesheet_button,
                text: text,
                background: { r: 220, g: 220, b: 220, a: 255 },
              )
    @next_spritesheet_button = @next_spritesheet_button.merge({
        id: :next_spritesheet_button,
        x: @current_spritesheet.x + @previous_spritesheet_button.w + 4,
        y: @previous_spritesheet_button.y,
        path: :next_spritesheet_button
    })
    args.state.buttons << @next_spritesheet_button

    # TODO: no way to add spritesheets.
    # text = "Create +"
    # @add_spritesheet_button = create_button(args,
    #             id: :add_spritesheet_button,
    #             text: text,
    #             background: { r: 220, g: 220, b: 220, a: 255 },
    #           )
    #  @add_spritesheet_button = @add_spritesheet_button.merge({
    #     id: :add_spritesheet_button,
    #     x: @current_spritesheet.x + @current_spritesheet.w - @add_spritesheet_button[:w],
    #     y: @current_spritesheet.y - @add_spritesheet_button.h - 8,
    #     path: :add_spritesheet_button
    #   })
    # args.state.buttons << @add_spritesheet_button

    if @selected_sprite
      rect = {
        x: @current_spritesheet.x + (@selected_sprite.source_x * EDITOR_TILE_SCALE),
        y: @current_spritesheet.y + (@selected_sprite.source_y * EDITOR_TILE_SCALE),
        h: @selected_sprite.source_h * EDITOR_TILE_SCALE,
        w: @selected_sprite.source_w * EDITOR_TILE_SCALE,
        r: 0,
        b: 0,
        g: 0,
        a: 55,
        primitive_marker: :sprite
      }

      args.outputs.sprites << rect
      args.outputs.sprites << create_borders(rect, border_width: 2, color: { r: 0, g: 0, b: 0, a: 200 }).values
    end
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
      x: sheet_border.x + 70,
      y: sheet_border.y - label_height + 8,
      text: sheet.name
    }

    # Always make background_tiles before sheet tiles.
    args.outputs[sheet_id].sprites << [background_tiles, sheet.tiles]
    args.outputs.sprites << [sheet_border, sheet.merge({ path: sheet_id })]
    args.outputs.labels << [label]
  end

  def render_current_nodeset(args)
    @current_nodeset = @nodesets[@selected_nodeset_index]
    # args.outputs.debug << "#{@current_nodeset}"
    # args.outputs.debug << "direction: #{@direction}"
    render_sheet(@current_nodeset, args)


    text = "<"
    @previous_nodeset_button = create_button(args,
                id: :previous_nodeset_button,
                text: text,
                background: { r: 220, g: 220, b: 220, a: 255 },
              )
    @previous_nodeset_button = @previous_nodeset_button.merge({
        id: :previous_nodeset_button,
        x: @current_nodeset.x,
        y: @current_nodeset.y - @previous_nodeset_button.h - 8,
        path: :previous_nodeset_button
    })

    args.state.buttons << @previous_nodeset_button

    text = ">"
    @next_nodeset_button = create_button(args,
                id: :next_nodeset_button,
                text: text,
                background: { r: 220, g: 220, b: 220, a: 255 },
              )
    @next_nodeset_button = @next_nodeset_button.merge({
        id: :next_nodeset_button,
        x: @current_nodeset.x + @previous_nodeset_button.w + 4,
        y: @previous_nodeset_button.y,
        path: :next_nodeset_button
    })
    args.state.buttons << @next_nodeset_button

    text = "Create +"
    @add_nodeset_button = create_button(args,
                id: :add_nodeset_button,
                text: text,
                background: { r: 220, g: 220, b: 220, a: 255 },
              )
     @add_nodeset_button = @add_nodeset_button.merge({
        id: :add_nodeset_button,
        x: @current_nodeset.x + @current_nodeset.w - @add_nodeset_button[:w],
        y: @current_nodeset.y - @add_nodeset_button.h - 8,
        path: :add_nodeset_button
      })
    args.state.buttons << @add_nodeset_button
  end

  def create_nodeset
    # columns always needs to be odd.
    columns = 11
    rows = 6
    h = rows * TILE_SIZE * EDITOR_TILE_SCALE
    w = columns * TILE_SIZE * EDITOR_TILE_SCALE
    @nodesets << {
      name: "nodeset__#{@nodesets.length + 1}",
      id: "nodeset__#{@nodesets.length + 1}",
      type: :nodeset,
      h: h,
      w: w,
      x: 20,
      y: 20.from_top - h,
      tiles: []
    }

    @selected_nodeset_index = @nodesets.length - 1
    @current_nodeset = @nodesets[@selected_nodeset_index]
    save_nodesets
  end

  def next_nodeset
    idx = @selected_nodeset_index + 1

    idx = 0 if idx > @nodesets.length - 1

    @selected_nodeset_index = idx
    @current_nodeset = @nodesets[@selected_nodeset_index]
  end

  def previous_nodeset
    idx = @selected_nodeset_index - 1

    idx = @nodesets.length - 1 if idx < 0

    @selected_nodeset_index = idx
    @current_nodeset = @nodesets[@selected_nodeset_index]
  end

  def next_spritesheet
    idx = @selected_spritesheet_index + 1

    idx = 0 if idx > @spritesheets.length - 1

    @selected_spritesheet_index = idx
    @current_spritesheet = @spritesheets[@selected_spritesheet_index]
  end

  def previous_spritesheet
    idx = @selected_spritesheet_index - 1

    idx = @spritesheets.length - 1 if idx < 0

    @selected_spritesheet_index = idx
    @current_spritesheet = @spritesheets[@selected_spritesheet_index]
  end

  # This method is for merging 2 sprites when a sprite > 16px.
  # Used for shift+click sprites.
  def combine_sprites(current_sprite, new_sprite)
    hash = {}

    hash[:source_x] = [new_sprite.source_x, current_sprite.source_x].min
    hash[:source_y] = [new_sprite.source_y, current_sprite.source_y].min

    if new_sprite.source_x > current_sprite.source_x
      hash[:source_w] = [current_sprite.source_w, new_sprite.source_x - current_sprite.source_x + new_sprite.source_w].max
    else
      hash[:source_w] = current_sprite.source_x - new_sprite.source_x + current_sprite.source_w
    end

    if new_sprite.source_y > current_sprite.source_y
      hash[:source_h] = [current_sprite.source_h, new_sprite.source_y - current_sprite.source_y + new_sprite.source_h].max
    else
      hash[:source_h] = current_sprite.source_y - new_sprite.source_y + current_sprite.source_h
    end

    current_sprite.merge(new_sprite).merge(hash)
  end

  def create_button(args, id:, text:, w: nil, h: nil, border_width: 1,
    background: {r: 0, g: 0, b: 0, a: 0},
    padding: {
      top: 8,
      left: 8,
      bottom: 8,
      right: 8,
    }
  )
    # render_targets only need to be created once, we use the the id to determine if the texture
    # has already been created
    args.state.created_buttons ||= {}
    return args.state.created_buttons[id] if args.state.created_buttons[id]

    if w.nil? && h.nil?
      w, h = $gtk.calcstringbox(text)
    end

    # original_w = w
    original_h = h.round
    w = (w + padding[:left] + padding[:right]).round
    h = (h + padding[:top] + padding[:bottom]).round

    # if the render_target hasn't been created, then generate it and store it in the created_buttons cache
    button = { created_at: Kernel.tick_count, id: id, w: w, h: h, text: text }
    args.state.created_buttons[id] = button

    # define the w/h of the texture
    args.outputs[id].w = w
    args.outputs[id].h = h

    border_width = border_width.round
    border_width_half = border_width.idiv(2)
    args.outputs[id].sprites << { x: border_width_half, y: border_width_half, w: w - border_width_half, h: h - border_width_half, **background, path: :pixel }

    # create a border
    args.outputs[id].borders << { x: 0, y: 0, w: w, h: h }

    # create a label centered vertically and horizontally within the texture
    args.outputs[id].labels << {
      x: 0 + padding[:left],
      y: original_h + padding[:bottom],
      text: text,
      # vertical_alignment_enum: 1,
      # alignment_enum: 1
    }

    args.state.created_buttons[id]
  end

  def sprite_to_nodeset_rect(mouse, sprite, nodeset)
      mouse_x = (mouse.x - nodeset.x)
      mouse_y = (mouse.y - nodeset.y)
      w = sprite.source_w * EDITOR_TILE_SCALE
      h = sprite.source_h * EDITOR_TILE_SCALE
      # prevent overflow right / left
      x = mouse_x.ifloor(TILE_SIZE * EDITOR_TILE_SCALE).clamp(0, nodeset.w - w)

      # prevent overflow up / down.
      y = mouse_y.ifloor(TILE_SIZE * EDITOR_TILE_SCALE).clamp(0, nodeset.h - h)

      sprite.merge({
        x: x,
        y: y,
        w: w,
        h: h,
      })
  end

  def create_borders(rect, border_width: 1, color: { r: 0, b: 0, g: 0, a: 255 })
      {
        top: {
          # top
          x: rect.x,
          w: rect.w,
          y: rect.y + rect.h,
          h: border_width,
          **color,
        },
        right: {
          # right
          x: rect.x + rect.w - border_width,
          w: border_width,
          y: rect.y,
          h: rect.h,
          **color,
        },
        bottom: {
          # bottom
          x: rect.x,
          w: rect.w,
          y: rect.y,
          h: border_width,
          **color,
        },
        left: {
          # left
          x: rect.x,
          w: border_width,
          y: rect.y,
          h: rect.h,
          **color,
        }
      }.each_value { |hash| hash[:primitive_marker] = :sprite }
  end

  def calc_nodes(args)
    mouse = args.inputs.mouse
    state = args.state
    # If a user has a sprite selected
    if @current_nodeset && @selected_sprite && mouse.intersect_rect?(@current_nodeset)
      new_sprite = sprite_to_nodeset_rect(mouse, @selected_sprite, @current_nodeset)

      intersecting_tiles = args.geometry.find_all_intersect_rect(new_sprite, @current_nodeset.tiles)

      if (mouse.click || (mouse.held && mouse.moved))
        intersecting_tiles.each { |tile| @current_nodeset.tiles.delete(tile) }
        @current_nodeset.tiles << new_sprite
        save_nodesets
      elsif intersecting_tiles.length > 0
        tile_target = {x: nil, y: nil, w: 0, h: 0, path: :pixel, r: 255, b: 0, g: 0, a: 128, primitive_marker: :sprite}

        intersecting_tiles.each do |tile|
          if !tile_target.x || tile_target.x < tile.x
            tile_target.x = tile.x
          end

          if !tile_target.y || tile_target.y < tile.y
            tile_target.y = tile.y
          end

          tile_target.w += tile.w
          tile_target.h += tile.h
        end

        sheet_id = "__sheet__#{@current_nodeset.id}"

        # sprite = sprite_to_nodeset_rect(args.inputs.mouse, tile_target, @current_nodeset)
        sprite = tile_target
        # sprite.y = @current_nodeset.y + sprite.y
        # sprite.x = @current_nodeset.x + sprite.x

        args.outputs[sheet_id].sprites << sprite
        args.outputs[sheet_id].sprites << create_borders(sprite, border_width: 2, color: { r: 100, g: 0, b: 0, a: 255 }).values
      end
    elsif @current_nodeset && !@selected_sprite && mouse.intersect_rect?(@current_nodeset)
      tiles = @current_nodeset.tiles.map do |current_tile|
        current_tile.merge({
          x: current_tile.x + @current_nodeset.x,
          y: current_tile.y + @current_nodeset.y,
          w: current_tile.w,
          h: current_tile.h
        })
      end

      tile = tiles.find { |tile| mouse.intersect_rect?(tile) }

      @hovered_node = tile

      if @hovered_node
        highlighted_hovered_node = @hovered_node.merge({ path: :pixel, r: 0, b: 255, g: 0, a: 64 })
        args.outputs.sprites << highlighted_hovered_node
        args.outputs.sprites << create_borders(highlighted_hovered_node, border_width: 2, color: {
          r: 0,
          g: 0,
          b: 255,
          a: 200,
        }).values
      end
    end

    if @hovered_node && args.inputs.mouse.intersect_rect?(@hovered_node) && args.inputs.mouse.click
      @selected_node = Camera.to_world_space(args.state.camera, @hovered_node).merge({
        w: @hovered_node.source_w,
        h: @hovered_node.source_h,

      })
    end

  end
end

