TILE_SIZE = 16

require "app/scenes/debug_scene.rb"

def tick(args)
  args.state.tile_size ||= TILE_SIZE

  args.state.scenes ||= {
    debug_scene: DebugScene.new
  }
  # initialize the scene to scene 1
  args.state.current_scene ||= :debug_scene

  current_scene = args.state.current_scene
  args.state.scenes[current_scene].tick(args)

  # make sure that the current_scene flag wasn't set mid tick
  if args.state.current_scene != current_scene
    raise "Scene was changed incorrectly. Set args.state.next_scene to change scenes."
  end

  if args.inputs.keyboard.key_down.r
    $gtk.reset
  end

  # if next scene was set/requested, then transition the current scene to the next scene
  if args.state.next_scene
    args.state.current_scene = args.state.next_scene
    args.state.next_scene = nil
  end
end

$gtk.reset
