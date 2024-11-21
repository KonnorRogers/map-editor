module Tilesheets
  # A simple tile.
  # @example
  #   require "app/tilesheets/tile.rb"
  #   module Tilesheets
  #     class Water < Tile
  #       def initialize(
  #         animation_frames: 4,
  #         animation_speed: 0.3,
  #         **kwargs
  #       )
  #         super(**kwargs)
  #         @animation_frames = animation_speed
  #         @animation_speed = animation_frames
  #       end

  #       def tile_size
  #         # This tile_size is "immutable". Its defined by the stylesheet.
  #         16
  #       end

  #       # Gets overriden by "@path"
  #       def default_path
  #         "sprites/sproutlands/tilesets/water.png"
  #       end

  #       # https://docs.dragonruby.org/#/samples/rendering-sprites?id=animation-using-sprite-sheet-mainrb
  #       def animate
  #         # Water animations are simple left -> right. 16px apart.
  #         @source_x = frame_index * tile_size
  #         self
  #       end
  #     end
  #   end
  class Tile
    # This never changes so make it a constant.
    FPS = 60

    attr_sprite
    attr_accessor :animation_speed, :animation_frames, :loop

    def self.call(*args, **kwargs, &block)
      self.new(*args, **kwargs, &block)
    end

    def initialize(
      w: nil,
      h: nil,
      tile_width: nil,
      tile_height: nil,
      animation_speed: nil,
      animation_duration: nil,
      **kwargs
    )
      @w = w || tile_width
      @h = h || tile_height

      # Use `source_*` to do more natural 0,0 is bottom-left.
      @source_x = 0
      @source_y = 0
      @source_w = tile_height
      @source_h = tile_width

      # Simple helper to "forward" keywords for sprite variables.
      kwargs.each do |k, v|
        instance_variable_set("@#{k}", v)
      end
    end

    def copy
      hash = {}
      instance_variables.each do |ivar|
        key = ivar.to_s.slice(1..).to_sym
        hash[key] = instance_variable_get(ivar)
      end

      self.class.new(**hash)
    end

    def merge(**kwargs)
      hash = {}
      instance_variables.each do |ivar|
        key = ivar.to_s.slice(1..).to_sym
        hash[key] = instance_variable_get(ivar)
      end

      hash = hash.merge(kwargs)

      self.class.new(**hash)
    end

    # Animate here is just a stub. In general for animateable tiles you should override this.
    # This should "mutate" the class in place. Usually source_x / source_y or by changing the @path.
    def animate
      self
    end

    # Simple helper for getting the current animation frame
    def frame_index
      0.frame_index(@animation_frames, frame_duration, true)
    end

    # Simple helper for converting an animation_speed -> frame_duration
    def frame_duration
      FPS * @animation_speed
    end
  end
end
