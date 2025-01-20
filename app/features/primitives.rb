class Primitives
  attr_accessor :created_buttons

  def initialize
    @created_buttons = {}
  end

  def create_button(args,
    id:,
    text:,
    w: nil,
    h: nil,
    background: {r: 0, g: 0, b: 0, a: 0},
    text_color: {r: 0, g: 0, b: 0, a: 255},
    border_color: {r: 0, g: 0, b: 0, a: 255},
    border_width: 1,
    padding: {
      top: 10,
      left: 10,
      bottom: 10,
      right: 10,
    }
  )
    # render_targets only need to be created once, we use the the id to determine if the texture
    # has already been created
    return @created_buttons[id] if @created_buttons[id]

    if w.nil? && h.nil?
      w, h = $gtk.calcstringbox(text, size_enum: 2)
    end

    # original_w = w
    original_h = h.round
    w = (w + padding[:left] + padding[:right]).round
    h = (h + padding[:top] + padding[:bottom]).round

    render_target_id = "button_primitive_#{id}".to_sym

    # define the w/h of the texture
    args.outputs[render_target_id].w = w
    args.outputs[render_target_id].h = h

    border_width = border_width.round
    border_width_half = border_width.idiv(2)

    btn = { x: border_width_half, y: 0, w: w - border_width, h: h - border_width, **background, path: :pixel }

    args.outputs[render_target_id].sprites << [
      btn
    ].concat(
      create_borders(btn, border_width: border_width, color: border_color).values
    )

    # create a label centered vertically and horizontally within the texture
    args.outputs[render_target_id].labels << {
      x: 0 + padding[:left],
      y: original_h + padding[:bottom],
      text: text,
      **text_color,
      # vertical_alignment_enum: 1,
      # alignment_enum: 1
      size_enum: 2,
    }

    # if the render_target hasn't been created, then generate it and store it in the created_buttons cache
    button = { created_at: Kernel.tick_count, id: id, w: w, h: h, text: text, path: render_target_id, render_target_id: render_target_id }
    @created_buttons[id] = button
    @created_buttons[id]
  end

  def create_borders(rect, padding: nil, border_width: 1, color: { r: 0, b: 0, g: 0, a: 255 })
    if padding && padding > 0
      rect = rect.merge({
        x: rect.x - padding,
        y: rect.y - padding,
        h: rect.h + (padding * 2),
        w: rect.w + (padding * 2),
      })
    end

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
      }.each_value do |hash|
        hash[:primitive_marker] = :sprite
        hash[:path] = :pixel
      end
  end
end
