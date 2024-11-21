module Tilesheets
  module Loader
    # @param [String] name - The name of the tilesheet
    # @path [String] path - The file path of the tilesheet
    # @param [Number] [tile_width=16] - The width of each tile
    # @param [Number] [tile_height=16] - The height of each tile
    def self.load_tiles(name:, path:, tile_width: 16, tile_height: 16)
      file_width, file_height = $gtk.calcspritebox(path)
      tiles = []

      rows = file_height.idiv(tile_height)
      columns = file_width.idiv(tile_width)

      rows.times do |y|
        columns.times do |x|
          tile_name = "#{name}__#{x.to_s.rjust(3, "0")}"

          source_x = x * tile_width
          source_y = y * tile_height

          tiles << {
            tilemap_name: name,
            tile_name: tile_name,
            source_x: source_x,
            source_y: source_y,
            source_h: tile_height,
            source_w: tile_width,
            path: path,
            animation_duration: nil,
            animation_frames: nil,
            x: x,
            y: y,
            h: tile_height,
            w: tile_width,
          }
        end
      end

      {
        name: name,
        tiles: tiles,
        columns: columns,
        rows: rows,
        path: path,
        w: file_width,
        h: file_height,
      }
    end
  end
end
