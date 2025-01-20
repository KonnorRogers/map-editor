# https://www.jvt.me/posts/2019/09/07/ruby-hash-keys-string-symbol/
module HashMethods
  # via https://stackoverflow.com/a/25835016/2257038
  def self.stringify_keys(hash)
    h = hash.map do |k,v|
      v_str = if v.instance_of? Hash
                self.stringify_keys(v)
              elsif v.instance_of? Array
                v.map { |item| self.stringify_keys(item) }
              else
                v
              end

      [k.to_s, v_str]
    end
    Hash[h]
  end

  # via https://stackoverflow.com/a/25835016/2257038
  def self.symbolize_keys(hash)
    h = hash.map do |k,v|
      v_sym = if v.instance_of? Hash
                self.symbolize_keys(v)
              elsif v.instance_of? Array
                v.map { |item| self.symbolize_keys(item) }
              else
                v
              end

      [k.respond_to?(:to_sym) ? k.to_sym : k, v_sym]
    end
    Hash[h]
  end
end
