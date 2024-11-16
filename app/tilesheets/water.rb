module Tilesheets
  class Water
    # This never changes so make it a constant.
    FPS = 60

    attr_sprite

    attr_accessor :animation_speed, :animation_frames, :tile_size

    def self.call(*args, **kwargs, &block)
      self.new(*args, **kwargs, &block)
    end

    def initialize(
      tile_size:,
      animation_frames: 4,
      animation_speed: 0.3,
      **kwargs
    )
      @animation_frames = animation_frames
      # in seconds
      @animation_speed = animation_speed

      @tile_size = tile_size

      # Simple helper to "forward" keywords for sprite variables.
      kwargs.each do |k, v|
        instance_variable_set("@#{k}", v)
      end

      @w ||= @tile_size
      @h ||= @tile_size

      # Use `source_*` to do more natural 0,0 is bottom-left.
      @source_x ||= 0
      @source_y ||= 0
      @source_w ||= sprite_tile_size
      @source_h ||= sprite_tile_size
      @path ||= default_path
    end

    def copy
      hash = {}
      instance_variables.each do |ivar|
        key = ivar.to_s.gsub(/^@/, "").to_sym
        hash[] = instance_variable_get(ivar)
      end

      new(**hash)
    end

    def merge(**kwargs)
      hash = {}
      instance_variables.each do |ivar|
        key = ivar.to_s.gsub(/^@/, "").to_sym
        hash[] = instance_variable_get(ivar)
      end

      hash.merge(kwargs)

      new(**hash)
    end

    def sprite_tile_size
      # This tile_size is "immutable". Its defined by the stylesheet.
      16
    end

    def default_path
      "sprites/sproutlands/tilesets/water.png"
    end

    def frame_duration
      FPS * animation_speed
    end

    # https://docs.dragonruby.org/#/samples/rendering-sprites?id=animation-using-sprite-sheet-mainrb
    def animate
      @source_y = 0

      # Water animations are simple left -> right. 16px apart.
      @source_x = tile_index * sprite_tile_size
      @source_w = sprite_tile_size
      @source_h = sprite_tile_size

      self
    end

    def tile_index
      0.frame_index(@animation_frames, frame_duration, true)
    end
  end
end
