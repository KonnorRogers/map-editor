require "app/scenes/map_editor_scene.rb"

TILE_SIZE = 16

def tick(args)
  args.outputs.debug << "Simulation FPS: #{args.gtk.current_framerate_calc.round.to_s}"
  args.state.tile_size ||= TILE_SIZE

  args.state.scenes ||= {
    map_editor_scene: MapEditorScene.new
  }

  args.state.text_fields ||= []
  args.state.text_fields.each do |input|
    input.tick

    next unless args.inputs.mouse.click

    if input.intersect_rect?(args.inputs.mouse)
      input.focus
    else
      input.blur
    end
  end

  # Output the inputs
  args.outputs.primitives << args.state.text_fields

  # initialize the scene to scene 1
  args.state.current_scene ||= :map_editor_scene

  current_scene = args.state.current_scene
  args.state.scenes[current_scene].tick(args)

  # make sure that the current_scene flag wasn't set mid tick
  if args.state.current_scene != current_scene
    raise "Scene was changed incorrectly. Set args.state.next_scene to change scenes."
  end

  if args.inputs.keyboard.key_down.r
    if !(args.state.text_fields && args.state.text_fields.any? { |input| input.focussed? })
      $gtk.reset
    end
  end

  # if next scene was set/requested, then transition the current scene to the next scene
  if args.state.next_scene
    args.state.current_scene = args.state.next_scene
    args.state.next_scene = nil
  end
end

$gtk.reset
