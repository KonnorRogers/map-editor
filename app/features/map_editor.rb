require "app/hash_methods.rb"
require "app/features/camera.rb"
require "app/tilesheets/loader.rb"
require "app/json.rb"
require "app/features/primitives.rb"
require "app/features/design_system/semantic_palette.rb"

class ::Array
  original_concat = instance_method(:concat)

  define_method(:concat) do |*arrays|
    bound_original_concat = original_concat.bind(self)
    arrays.each { |array| bound_original_concat.call(array) }
    self
  end
end

class MapEditor
  attr :mode, :hovered_tile, :selected_tile, :spritesheet_rect

  TILE_SIZE = 16
  EDITOR_TILE_SCALE = 2

  def initialize
    @primitives = Primitives.new
    @palette = DesignSystem::SemanticPalette.new

    # @type [:add, :select, :remove]
    @mode = :add

    # @type [:spritesheet, :map]
    @view = :map

    # Set this to transition between map / spritesheet
    @next_view = nil

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

    @nodesets.each do |nodeset|
      nodeset.type = :nodeset
    end

    @selected_spritesheet_index = 0
    @current_nodeset_index = 0
  end

  def render_tiles(args)
    return if @view != :map

    state = args.state

    tiles = []
    state.layers.each do |layer|
      tiles_to_render = Camera.find_all_intersect_viewport(state.camera, layer.tiles)
      tiles.concat(tiles_to_render.map { |m| Camera.to_screen_space(state.camera, m) })
    end
    args.outputs[:scene].sprites << tiles
  end

  def render_sprite_canvas(args)
    to_render_target = ->(index) { ("__spritesheet_canvas__#{index}").to_sym }

    args.state.spritesheet_tiles = []

    if !args.state.sprites
      args.state.spritesheet_target = []

      @spritesheets.each_with_index do |spritesheet, index|
        render_target = to_render_target.call(index)
        args.outputs[render_target].w = spritesheet.w
        args.outputs[render_target].h = spritesheet.h
        args.outputs[render_target].background_color = [0, 0, 0, 0]
        args.outputs[render_target].sprites << spritesheet.tiles.map do |sprite|
          sprite.x = sprite.source_x
          sprite.y = sprite.source_y
          sprite.w = sprite.source_w
          sprite.h = sprite.source_h
          sprite.dup
        end
      end
    end

    return if @view != :spritesheet

    prev_x = ((Camera::SCREEN_WIDTH / -4)).ifloor(TILE_SIZE)

    y = 0 # (Camera::SCREEN_HEIGHT / -4)
    gap = TILE_SIZE

    # @rendered_spritesheets = []
    @spritesheets.each_with_index do |spritesheet, index|
      render_target = to_render_target.call(index)

      if index > 0
        prev_x += @spritesheets[index - 1].file_width + gap
      end

      spritesheet_rect = {
        x: prev_x,
        y: y,
        w: spritesheet.file_width,
        h: spritesheet.file_height,
        path: render_target
      }

      if Camera.intersect_viewport?(args.state.camera, spritesheet_rect)
        spritesheet_target = Camera.to_screen_space(args.state.camera, spritesheet_rect)

        label = {
          x: spritesheet_target.x,
          y: spritesheet_target.y - (8 * args.state.camera.scale).ceil,
          text: "#{spritesheet.name}",
          primitive_marker: :label,
          size_px: (16 * args.state.camera.scale).ceil
        }

        args.state.spritesheet_tiles.concat(spritesheet.tiles.map do |sprite|
          sprite = sprite.dup
          sprite.x = spritesheet_rect.x + (sprite.x)
          sprite.y = spritesheet_rect.y + (sprite.y)
          sprite
        end)

        args.outputs[:scene].sprites << [
          spritesheet_target,
          @primitives.create_borders(spritesheet_target, border_width: 1, color: {r: 0, b: 0, g: 0, a: 255}).values
        ]
        args.outputs[:scene].labels << label
      end
    end
  end

  def tick(args)
    args.state.buttons ||= []

    args.outputs.debug << @view.to_s
    args.outputs.debug << @mode.to_s

    render_menu(args)
    render_pixel_grid(args)
    render_tiles(args)
    render_sprite_canvas(args)
    load_layers(args) if args.state.tick_count <= 0
    render_current_nodeset(args)
    calc(args)
    render(args)
    handle_nodeset_buttons(args)
    handle_spritesheet_buttons(args)
    switch_mode(args)
    transition_view(args)
  end

  def transition_view(args)
    if @next_view && @next_view != @view
      @view = @next_view
      @next_view = nil
      @selected_sprite = nil
      @selected_node = nil
      @select_rect = nil
      args.state.camera.x = 0
      args.state.camera.target_x = 0
      args.state.camera.y = 0
      args.state.camera.target_y = 0
    end
  end


  def render_menu(args)
    render_target = :editor_menu

    args.outputs[render_target].w = Camera::SCREEN_WIDTH / 3
    args.outputs[render_target].h = Camera::SCREEN_HEIGHT
    args.outputs[render_target].background_color = [0, 255, 255, 255]
    menu = args.outputs[render_target]
    args.outputs[render_target].sprites << {x: menu.w - 3, y: 0, h: menu.h, w: 3, r: 0, g: 0, b: 0, a: 255}

    @spritesheet_menu_button = @primitives.create_button(args,
      id: :spritesheet_menu_button,
      text: "Spritesheets",
      background: @palette.colors.dig(:neutral, :fill, :loud),
      text_color: @palette.colors.dig(:neutral, :on, :loud),
    ).merge({
      x: 20,
      y: 360,
    })

    @map_menu_button = @primitives.create_button(args,
      id: :map_menu_button,
      text: "Map",
      background: @palette.colors.dig(:neutral, :fill, :loud),
      text_color: @palette.colors.dig(:neutral, :on, :loud),
    ).merge({
      x: @spritesheet_menu_button.x + @spritesheet_menu_button.w + 10,
      y: @spritesheet_menu_button.y,
    })

    buttons = [@spritesheet_menu_button, @map_menu_button]

    Geometry.find_all_intersect_rect(args.inputs.mouse, buttons).each do |button|
      button.merge!({
        **@palette.colors.dig(:neutral, :fill, :normal)
      })
    end


    args.state.buttons.concat(buttons)

    mouse = args.inputs.mouse

    if mouse.click && mouse.intersect_rect?(@spritesheet_menu_button)
      @next_view = :spritesheet
    end

    if mouse.click && mouse.intersect_rect?(@map_menu_button)
      @next_view = :map
    end

    args.outputs[render_target].sprites << [@spritesheet_menu_button, @map_menu_button]
    @menu = {x: 0, y: 0, w: menu.w, h: menu.h, path: render_target}
    args.outputs.sprites << @menu
  end

  def render_pixel_grid(args)
    grid_border_size = 1
    width = 1280
    height = 1280
    if Kernel.tick_count == 0
      args.outputs[:grid].w = width
      args.outputs[:grid].h = height
      args.outputs[:grid].background_color = [0, 0, 0, 0]
      @grid = []
      height.idiv(TILE_SIZE).each do |x|
        width.idiv(TILE_SIZE).each do |y|
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
      args.outputs[:grid].sprites << @grid
    end

    args.state.grid_boxes ||= 10.flat_map do |x|
      10.map do |y|
        { x: (x - 5) * 1280, y: (y - 5) * 1280, w: 1280, h: 1280, path: :grid, r: 0, b: 0, g: 0, a: 64 }
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

    if mouse.intersect_rect?(@delete_nodeset_button)
      delete_nodeset
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
  end

  def calc_hovered_sprite(args)
    @hovered_sprite = Geometry.find_all_intersect_rect(@mouse_world_rect, args.state.spritesheet_tiles)[-1]

    if @hovered_sprite
      # mouse = Camera.to_screen_space(args.state.camera, @mouse_world_rect)
      # @hovered_sprite# .merge({ x: mouse.x, y: mouse.y })
    end
  end

  def calc(args)
    inputs = args.inputs
    mouse = inputs.mouse
    state = args.state

    tile_width = TILE_SIZE
    tile_height = TILE_SIZE

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

    calc_hovered_sprite(args)

    if @hovered_sprite && !args.inputs.mouse.intersect_rect?(@current_nodeset)
      # make a new sprite.
      selected_sprite = @hovered_sprite.merge({})

      if mouse.click
        # Clear any selected nodes
        @selected_node = nil

        if @selected_sprite && args.inputs.keyboard.shift
          sprite = combine_sprites(@selected_sprite, selected_sprite)
          sprite.x = [@selected_sprite.x, sprite.x].min
          sprite.y = [@selected_sprite.y, sprite.y].min
          sprite.w = sprite.source_w
          sprite.h = sprite.source_h
          @selected_sprite = sprite
        else
          @selected_sprite = selected_sprite
        end
      elsif args.inputs.keyboard.shift && @selected_sprite
        sprites = []
        sprite = combine_sprites(@selected_sprite, selected_sprite)

        sprite.x = [@selected_sprite.x, sprite.x].min
        sprite.y = [@selected_sprite.y, sprite.y].min
        sprite.w = sprite.source_w
        sprite.h = sprite.source_h

        sprite = Camera.to_screen_space(args.state.camera, sprite.merge({
          path: :pixel,
          r: 0, g: 0, b: 0, a: 64
        }))

        sprites << sprite
        sprites << @primitives.create_borders(sprite, border_width: 2, color: { r: 0, b: 0, g: 0, a: 200 }).values
        args.outputs[:scene].sprites << sprites
      end

    end

    if @selected_sprite
      @selected_sprite.merge!({
        w: @selected_sprite.source_w,
        h: @selected_sprite.source_h
      })

      selected_sprite = Camera.to_screen_space(args.state.camera, @selected_sprite).merge({ path: :pixel, r: 0, g: 0, b: 0, a: 100 })
      selected_sprite_borders = @primitives.create_borders(selected_sprite, border_width: 2, color: { r: 100, b: 100, g: 100, a: 255 }).values
      args.outputs[:scene].sprites << [selected_sprite, selected_sprite_borders]
    end

    # Must come before "@mode" changes
    calc_nodes(args)

    if @mode == :remove && (mouse.click || (mouse.held && mouse.moved))
      @should_save = true
      intersecting_tiles = Geometry.find_all_intersect_rect(@mouse_world_rect, args.state.layers[@current_layer].tiles)
      intersecting_tiles.each { |t| args.state.layers[@current_layer].tiles.delete(t) }
    elsif @mode == :select
      handle_box_select(args)
    # TODO: Change to "@selected_node"
    elsif @selected_node && (mouse.click || (mouse.held && mouse.moved))
      if @mode == :add
        @should_save = true
        intersecting_tiles = args.state.geometry.find_all_intersect_rect(@selected_node, args.state.layers[@current_layer].tiles)
        intersecting_tiles.each { |t| args.state.layers[@current_layer].tiles.delete(t) }
        args.state.layers[@current_layer].tiles << @selected_node.copy
      end
    end

    # Purposely delay saving until `mouse.up` because other wise the editor lags a lot.
    if mouse.up && @should_save
      @should_save = false
      save_tiles(args)
    end
  end

  def switch_mode(args)
    if args.state.text_fields.any? { |input| input.focussed? }
      return
    end

    if args.inputs.keyboard.key_down.n
      @current_nodeset_index += 1

      if @current_nodeset_index > @nodesets.length - 1
        @current_nodeset_index = 0
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
    sprites = []

    scene_sprites = []

    if @mode == :remove
      hovered_tile = args.state.layers[@current_layer].tiles.find { |t| t.intersect_rect?(@mouse_world_rect) }

      if hovered_tile
        alpha_channel = (Camera.to_screen_space(state.camera, hovered_tile)).merge(path: :pixel, r: 255, g: 0, b: 0, a: 128)
        alpha_channel_borders = @primitives.create_borders(alpha_channel, border_width: 2, color: {r: 255, b: 0, g: 0, a: 255}).values
        scene_sprites << alpha_channel
        scene_sprites.concat(alpha_channel_borders)
      end
    end

    if @mode == :add && @selected_node
      hovered_tiles = args.state.layers[@current_layer].tiles.select { |t| t.intersect_rect?(@selected_node) }

      if hovered_tiles.length > 0
        hovered_tiles.each do |hovered_tile|
          world_hovered_tile = (Camera.to_screen_space(state.camera, hovered_tile)).merge(path: :pixel, r: 255, g: 0, b: 0, a: 128)
          scene_sprites << world_hovered_tile
          scene_sprites << @primitives.create_borders(world_hovered_tile, border_width: 2, color: { r: 255, g: 0, b: 0, a: 255 }).values
        end
      end
    end

    if @hovered_sprite
      world_hovered_sprite = Camera.to_screen_space(state.camera, @hovered_sprite).merge({
                           path: :pixel,
                           r: 0, g: 0, b: 128, a: 64
                 })

      scene_sprites << world_hovered_sprite
      scene_sprites << @primitives.create_borders(world_hovered_sprite, border_width: 2, color: { r: 0, b: 255, g: 0, a: 200 }).values
    end

    if @selected_sprite
      sheet_id = "__sheet__#{@current_nodeset.id}"

      if args.inputs.mouse.intersect_rect?(@current_nodeset)
        sprite = sprite_to_nodeset_rect(args.inputs.mouse, @selected_sprite, @current_nodeset)
        outputs[sheet_id].sprites << sprite
        outputs[sheet_id].sprites << sprite.merge(path: :pixel, r: 0, g: 255, b: 0, a: 30)
        outputs[sheet_id].sprites << @primitives.create_borders(sprite, border_width: 2, color: { r: 0, g: 100, b: 0, a: 255 }).values
      elsif @hovered_sprite.nil? && !args.inputs.mouse.intersect_rect?(@current_nodeset)
        screen_selected_sprite = (Camera.to_screen_space(state.camera, @selected_sprite.merge({x: @mouse_world_rect.x, y: @mouse_world_rect.y })))
        scene_sprites << screen_selected_sprite
        scene_sprites << screen_selected_sprite.merge(path: :pixel, r: 255, g: 0, b: 0, a: 64)
      end
    end


    if @selected_node
      @selected_node.x = @mouse_world_rect.x
      @selected_node.y = @mouse_world_rect.y

      selected_node = (Camera.to_screen_space(state.camera, @selected_node))
      scene_sprites << selected_node
      selected_node_bg = selected_node.merge({ path: :pixel, r: 0, g: 255, b: 0, a: 20 })
      scene_sprites << @primitives.create_borders(selected_node_bg, border_width: 2, color: {
        r: 0,
        g: 255,
        b: 0,
        a: 255,
      }).values
      scene_sprites << selected_node_bg
    end
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
    args.state.layers[@current_layer].tiles.reject! { |t| t.intersect_rect? selection }
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
        args.state.layers[@current_layer].tiles << @selected_node.merge({
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
      layers: args.state.layers
    })
    $gtk.write_file("data/layers.json", contents)
  end

  def load_layers(args)
    return if args.state.layers

    args.state.layers = []

    begin
      json = $gtk.parse_json_file("data/layers.json")
      layers = json["layers"].map do |layer|
        HashMethods.symbolize_keys(layer)
      end
      args.state.layers = layers
    rescue => e
    end

    if args.state.layers.length <= 0
      add_layer(args.state.layers)
    end

    @current_layer = args.state.layers.length - 1
  end

  def add_layer(layers)
    layers << {
      tiles: []
    }
  end

  def scale_nodeset(nodeset)
    nodeset.x = nodeset.source_x
    nodeset.y = ((nodeset.source_y) - (nodeset.source_h))
    nodeset.h = nodeset.source_h * EDITOR_TILE_SCALE
    nodeset.w = nodeset.source_w * EDITOR_TILE_SCALE
    nodeset.scaled_tiles = nodeset.tiles.map do |tile|
      tile.merge({
        x: nodeset.x + (tile.x * EDITOR_TILE_SCALE),
        y: nodeset.y + (tile.y * EDITOR_TILE_SCALE),
        w: tile.source_w * EDITOR_TILE_SCALE,
        h: tile.source_h * EDITOR_TILE_SCALE,
      })
    end
    nodeset
  end

  def load_nodesets
    nodesets = []
    begin
      json = $gtk.parse_json_file("data/nodesets.json")

      if json
        nodesets = json["nodesets"].map do |nodeset|
          nodeset = HashMethods.symbolize_keys(nodeset)
          scale_nodeset(nodeset)
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

  def render_sheet(sheet, args)
    sheet_id = "__sheet__#{sheet.id}".to_sym
    args.outputs[sheet_id].w = sheet.source_w
    args.outputs[sheet_id].h = sheet.source_h

    background_tiles = []

    rows = sheet.source_h.idiv(TILE_SIZE)
    columns = sheet.source_w.idiv(TILE_SIZE)

    # For even columns, we need an extra column to make it odd and get the pattern.
    if columns.mod(2) <= 0
      columns += 1
    end

    count = 0
    rows.times do |row|
      columns.times do |column|
        count += 1
        x = column * TILE_SIZE
        y = row * TILE_SIZE

        background = (count % 2).to_i == 0 ? { r: 230, g: 230, b: 230 } : { r: 180, g: 180, b: 180 }

        background_tiles << {
          x: x,
          y: y,
          h: TILE_SIZE,
          w: TILE_SIZE,
          path: :pixel,
        }.merge!(background)
      end
    end

    _label_width, label_height = $gtk.calcstringbox(sheet.name)
    scaled_sheet = {x: sheet.x, y: sheet.y, w: sheet.source_w * EDITOR_TILE_SCALE, h: sheet.source_h * EDITOR_TILE_SCALE, path: sheet_id}
    scaled_sheet_border = { x: scaled_sheet.x - 2, y: scaled_sheet.y - 2, w: scaled_sheet.w + 4, h: scaled_sheet.h + 4, r: 0, g: 0, b: 0, a: 255, path: :pixel }

    label = {
      x: scaled_sheet_border.x,
      y: scaled_sheet_border.y - label_height - 40,
      text: sheet.name,
      size_enum: 2,
    }

    hovered_nodes = []
    if @hovered_node
      # args.outputs.debug << "#{@hovered_node}"
      highlighted_hovered_node = @hovered_node.merge({ path: :pixel, r: 0, b: 255, g: 0, a: 64 })
      hovered_nodes << highlighted_hovered_node
      hovered_nodes.concat(@primitives.create_borders(highlighted_hovered_node, border_width: 2, color: {
        r: 0,
        g: 0,
        b: 255,
        a: 200,
      }).values)
    end

    # Always make background_tiles before sheet tiles.
    args.outputs[sheet_id].sprites.concat(background_tiles, sheet.tiles)
    args.outputs.sprites.concat(
      [
        scaled_sheet_border,
        scaled_sheet,
      ],
      hovered_nodes
    )
    args.outputs.labels << [label]
  end

  def render_current_nodeset(args)
    @current_nodeset = @nodesets[@current_nodeset_index]

    render_sheet(@current_nodeset, args)

    text = "<"
    @previous_nodeset_button = @primitives.create_button(args,
                id: :previous_nodeset_button,
                text: text,
                background: @palette.colors.dig(:neutral, :fill, :loud),
                text_color: @palette.colors.dig(:neutral, :on, :loud),
              )
    @previous_nodeset_button = @previous_nodeset_button.merge({
        id: :previous_nodeset_button,
        x: @current_nodeset.x,
        y: @current_nodeset.y - @previous_nodeset_button.h - 8,
    })

    args.state.buttons << @previous_nodeset_button

    text = ">"
    @next_nodeset_button = @primitives.create_button(args,
                id: :next_nodeset_button,
                text: text,
                background: @palette.colors.dig(:neutral, :fill, :loud),
                text_color: @palette.colors.dig(:neutral, :on, :loud),
              )
    @next_nodeset_button = @next_nodeset_button.merge({
        id: :next_nodeset_button,
        x: @current_nodeset.x + @previous_nodeset_button.w + 4,
        y: @previous_nodeset_button.y,
    })
    args.state.buttons << @next_nodeset_button

    text = "Delete"
    @delete_nodeset_button = @primitives.create_button(args,
      id: :delete_nodeset_button,
      text: text,
      background: @palette.colors.dig(:danger, :fill, :loud),
      text_color: @palette.colors.dig(:danger, :on, :loud),
    )
     @delete_nodeset_button = @delete_nodeset_button.merge({
        id: :add_nodeset_button,
        x: @menu.x + @menu.w - @delete_nodeset_button.w - 16,
        y: @next_nodeset_button.y,
      })

    args.state.buttons << @delete_nodeset_button

    text = "Create"
    @add_nodeset_button = @primitives.create_button(args,
                id: :add_nodeset_button,
                text: text,
                background: @palette.colors.dig(:neutral, :fill, :loud),
                text_color: @palette.colors.dig(:neutral, :on, :loud),
              )
     @add_nodeset_button = @add_nodeset_button.merge({
        id: :add_nodeset_button,
        x: @delete_nodeset_button.x - @add_nodeset_button.w - 8,
        y: @next_nodeset_button.y,
      })

    args.state.buttons << @add_nodeset_button
  end

  def create_nodeset
    # columns always needs to be odd.
    columns = 11
    rows = 6
    h = rows * TILE_SIZE
    w = columns * TILE_SIZE
    @nodesets << scale_nodeset({
      name: "nodeset__#{@nodesets.length + 1}",
      id: "nodeset__#{@nodesets.length + 1}",
      type: :nodeset,
      source_h: h,
      source_w: w,
      source_x: 20,
      source_y: 20.from_top - h,
      tiles: []
    })

    @current_nodeset_index = @nodesets.length - 1
    @current_nodeset = @nodesets[@current_nodeset_index]
    save_nodesets
  end

  def next_nodeset
    idx = @current_nodeset_index + 1

    idx = 0 if idx > @nodesets.length - 1

    @current_nodeset_index = idx
    @current_nodeset = @nodesets[@current_nodeset_index]
  end

  def previous_nodeset
    idx = @current_nodeset_index - 1

    idx = @nodesets.length - 1 if idx < 0

    @current_nodeset_index = idx
    @current_nodeset = @nodesets[@current_nodeset_index]
  end

  def delete_nodeset
    return if @nodesets.length <= 1 # cannot delete all nodesets.
    idx = @current_nodeset_index
    if idx == 0
      @nodesets = @nodesets.slice(1..-1)
    else
      previous_nodeset
      @nodesets.delete_at(idx)
    end
    save_nodesets
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

  def sprite_to_nodeset_rect(mouse, sprite, nodeset)
      mouse_x = (mouse.x - nodeset.x) / EDITOR_TILE_SCALE
      mouse_y = (mouse.y - nodeset.y) / EDITOR_TILE_SCALE
      w = sprite.source_w
      h = sprite.source_h
      # prevent overflow right / left
      x = mouse_x.ifloor(TILE_SIZE).clamp(0, nodeset.w - w)

      # prevent overflow up / down.
      y = mouse_y.ifloor(TILE_SIZE).clamp(0, nodeset.h - h)

      sprite.merge({
        x: x,
        y: y,
        w: w,
        h: h,
      })
  end

  def calc_nodes(args)
    mouse = args.inputs.mouse

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
        args.outputs[sheet_id].sprites << @primitives.create_borders(sprite, border_width: 2, color: { r: 100, g: 0, b: 0, a: 255 }).values
      end
    end

    if @current_nodeset && !@selected_sprite && mouse.intersect_rect?(@current_nodeset)
      tile = @current_nodeset.scaled_tiles.find { |tile| mouse.intersect_rect?(tile) }

      @hovered_node = tile
    else
      @hovered_node = nil
    end

    mouse = args.inputs.mouse
    if @hovered_node && mouse.intersect_rect?(@hovered_node) && mouse.click
      @selected_node = Camera.to_world_space(args.state.camera, @hovered_node).merge({
        w: @hovered_node.source_w,
        h: @hovered_node.source_h,
      })
      @mode = :add
    end
  end
end

