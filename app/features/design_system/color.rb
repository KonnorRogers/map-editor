module DesignSystem
  module Color
    # Usage
    # DesignSystem::Color.from("#fff")
    # => { r: 255, g: 255, b: 255, a: 255 }
    def self.hex_to_rgba(str_int, order = 432)
      if String === str_int
        str = str_int.delete_prefix("#")
        strl = str.length
        r, g, b, a = case strl
        when 1
          c = [str * 2].pack("H*").ord
          [c, c, c, c]
        when 3
          cs = (str + "f").chars
          [cs.zip(cs).flatten.join].pack("H*").bytes
        when 4
          cs = str.chars
          [cs.zip(cs).flatten.join].pack("H*").bytes
        when 6
          [str + "ff"].pack("H*").bytes
        when 8
          [str].pack("H*").bytes
        else
          raise "Invalid hex format"
        end
      elsif Integer === str_int
        case order
        when 432
          r = (str_int >> 16) & 0xff
          g = (str_int >> 8) & 0xff
          b = (str_int) & 0xff
          a = 0xff
        when 4321
          r = (str_int >> 24) & 0xff
          g = (str_int >> 16) & 0xff
          b = (str_int >> 8) & 0xff
          a = (str_int) & 0xff
        when 234
          r = (str_int) & 0xff
          g = (str_int >> 8) & 0xff
          b = (str_int >> 16) & 0xff
          a = 0xff
        when 1234
          r = (str_int) & 0xff
          g = (str_int >> 8) & 0xff
          b = (str_int >> 16) & 0xff
          a = (str_int >> 24) & 0xff
        end
      end

      {
        r: r,
        g: g,
        b: b,
        a: a
      }
    end
  end
end
