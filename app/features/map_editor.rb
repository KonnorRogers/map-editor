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
    end

    @selected_spritesheet_index = 0
    @selected_nodeset_index = 0
  end

  def tick(args)
    args.state.buttons ||= []
    load_tiles(args) if args.state.tick_count <= 0
    render_current_spritesheet(args) # if args.state.tick_count <= 0
    render_current_nodeset(args)
    calc(args)
    render(args)
    handle_nodeset_buttons(args)
    handle_spritesheet_buttons(args)
    switch_mode(args)
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
        @hovered_sprite = tile
      else
        @hovered_sprite = nil
      end
    else
      @hovered_sprite = nil
    end

    if mouse.click && @hovered_sprite
      selected_sprite = @hovered_sprite.merge({})

      if @selected_sprite && args.inputs.keyboard.shift
        @selected_sprite = combine_sprites(@selected_sprite, selected_sprite)
      else
        @selected_sprite = selected_sprite
      end

      @selected_sprite.merge!({
        w: @selected_sprite.source_w,
        h: @selected_sprite.source_h
      })
    end

    if @selected_sprite
      tile_width = @selected_sprite.w
      tile_height = @selected_sprite.h

      ifloor_x = world_mouse.x.ifloor(tile_width)
      ifloor_y = world_mouse.y.ifloor(tile_height)
      @mouse_world_rect = { x: ifloor_x,
                            y: ifloor_y,
                            w: tile_width,
                            h: tile_height }

      # args.outputs.debug << "y: #{@mouse_world_rect.y}, x: #{@mouse_world_rect.x}"
      @selected_sprite.x = @mouse_world_rect.x
      @selected_sprite.y = @mouse_world_rect.y
    else
    end

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
        intersecting_tiles = args.state.geometry.find_all_intersect_rect(@mouse_world_rect, args.state.tiles)
        intersecting_tiles.each { |t| args.state.tiles.delete(t) }
        args.state.tiles << @selected_node.copy
      end
    end

    if @selected_sprite && (mouse.click || (mouse.held && mouse.moved)) && mouse.intersect_rect?(@current_nodeset)
      new_sprite = sprite_to_nodeset_rect(mouse, @selected_sprite, @current_nodeset)

      intersecting_tiles = args.geometry.find_all_intersect_rect(new_sprite, @current_nodeset.tiles)
      intersecting_tiles.each { |tile| @current_nodeset.tiles.delete(tile) }
      @current_nodeset.tiles << new_sprite
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
    end

    if args.inputs.keyboard.s
      @mode = :select
      @selected_sprite = nil
    end

    if args.inputs.keyboard.a
      @mode = :add
    end

    if args.inputs.mouse.click && @hovered_sprite
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

    if @hovered_sprite
      sprites << @hovered_sprite.merge({ x: @hovered_sprite.x,
                           y: @hovered_sprite.y,
                           w: @hovered_sprite.w,
                           h: @hovered_sprite.h,
                           path: :pixel,
                           r: 0, g: 0, b: 128, a: 64 })

      sprites << create_borders(@hovered_sprite, border_width: 1, color: { r: 0, b: 255, g: 0, a: 255 }).values
    end

    if @mode == :remove
      hovered_tile = args.state.tiles.find { |t| t.intersect_rect?(@mouse_world_rect) }

      if hovered_tile
        scene_sprites << (Camera.to_screen_space(state.camera, hovered_tile)).merge(path: :pixel, r: 255, g: 0, b: 0, a: 64)
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
        outputs[sheet_id].sprites << sprite.merge(path: :pixel, r: 0, g: 255, b: 255, a: 64)
      end
    end

    # args.outputs.debug << "nodeset tiles: #{@current_nodeset.tiles.length}"

    outputs.sprites << [sprites, args.state.buttons]
    outputs[:scene].sprites << scene_sprites
    # args.outputs.debug << "#{@current_nodeset}"
    # outputs[@current_nodeset.id] << @selected_sprite

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
    return if @selected_sprite.nil?

    select_rect = select_rect_to_tiles(args)
    columns = select_rect.w.idiv(@selected_sprite.w).floor
    rows = select_rect.h.idiv(@selected_sprite.h).floor

    remove_tiles(args, select_rect)

    columns.times do |col|
      rows.times do |row|
        args.state.tiles << @selected_sprite.merge({
          x: select_rect.x + (col * @selected_sprite.w),
          y: select_rect.y + (row * @selected_sprite.h),
          w: @selected_sprite.w,
          h: @selected_sprite.h
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

  def save_nodesets
  end

  def delete_nodeset
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

    # Find the direction, left / right or up / down
    # y_range = ((current_sprite.source_y)..(current_sprite.source_y + current_sprite.source_h))
    # x_range = ((current_sprite.source_x)..(current_sprite.source_x + current_sprite.source_w))

    # if is_horizontal

    # end

    if new_sprite.source_y > current_sprite.source_y
      # @direction = :up
      hash[:source_y] = current_sprite.source_y
      hash[:source_h] = (new_sprite.source_y - current_sprite.source_y + new_sprite.source_h)
    elsif current_sprite.source_y > new_sprite.source_y
      # @direction = :down
      hash[:source_y] = current_sprite.source_y - new_sprite.source_h
      hash[:source_h] = current_sprite.source_h + new_sprite.source_h
    elsif new_sprite.source_x > current_sprite.source_x
      # @direction = :right
      hash[:source_x] = current_sprite.source_x
      hash[:source_w] = (new_sprite.source_x - current_sprite.source_x + new_sprite.source_w)
    elsif current_sprite.source_x > new_sprite.source_x
      # @direction = :left
      hash[:source_x] = current_sprite.source_x - new_sprite.source_w
      hash[:source_w] = current_sprite.source_w + new_sprite.source_w
    end

    @direction = hash

    # @direction = {
    #   x1: current_sprite.source_x,
    #   x2: new_sprite.source_x,
    #   y1: current_sprite.source_y,
    #   y2: new_sprite.source_y,
    #   w1: current_sprite.w,
    #   w2: new_sprite.source_w,
    #   h1: current_sprite.h,
    #   h2: new_sprite.source_h,
    # }
    @direction = new_sprite.merge(
      current_sprite,
    ).merge(
      hash
    )

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
          w: rect.w + border_width,
          y: rect.y + rect.h,
          h: border_width,
          **color,
        },
        right: {
          # right
          x: rect.x + rect.w,
          w: border_width,
          y: rect.y,
          h: rect.h,
          **color,
        },
        bottom: {
          # bottom
          x: rect.x,
          w: rect.w + border_width,
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
      }
  end
end
