module JSON
  # Primitive for turning a value into a JSON string. Right now it supports Hash, Numeric, String, Symbol, Array, and nil.
  def self.to_json_value(value, spacer, depth)
    return "null" if value.nil?

    return value.to_s if value.is_a?(Numeric)

    return "\"#{value.to_s.gsub('"', "'\"'")}\"" if value.is_a?(String) || value.is_a?(Symbol)

    if value.is_a?(Hash)
      inner_depth = depth + 1
      strings = value.map do |k, v|
        "#{spacer * inner_depth}" + to_json_value(k, spacer, inner_depth) + ": " + to_json_value(v, spacer, inner_depth)
      end.join(",\n")

      leading_space = "#{spacer * depth}"
      return "{\n" + strings + "\n#{leading_space}}"
    end

    if value.is_a?(Array)
      inner_depth = depth + 1
      strings = value.map do |v|
        "#{spacer * inner_depth}" + to_json_value(v, spacer, inner_depth)
      end.join(",\n")

      leading_space = "#{spacer * depth}"
      return "[\n" + strings + "\n#{leading_space}]"
    end

    raise "Value is not of type String, Symbol, Hash, Numeric, Array, or nil"
  end

  # down and dirty to_json. Just hashes, numbers, symbols, strings, array, and nil.
  def self.to_json(hash, spacer = "  ", depth = 1)
    strs = []

    hash.each do |k, v|
      strs << "#{spacer * depth}\"#{k}\": #{to_json_value(v, spacer, depth)}"
    end

    "{\n" + strs.join(",\n") + "\n}"
  end
end
