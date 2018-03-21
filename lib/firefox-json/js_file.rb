require 'extlz4'
require 'oj'

module FirefoxJson
  # Saves and restores files
  module JsFile
    MOZ_ID = "mozLz40\0"
    MOZ_PREFIX = MOZ_ID.size + 4
    MAX_SIZE = 1 << 32 - 1
    OFFSETS = [1 << 24, 1 << 16, 1 << 8, 1]

    class FileTooLarge < RuntimeError; end

    def self.load_file(path)
      load(IO.read(path))
    end

    def self.load(string)
      if string[0, MOZ_ID.size] == MOZ_ID
        string = decompress(string)
      end
      Oj.load(string, mode: :strict)
    end

    def self.save(path, data)
      string = Oj.dump(data, mode: :strict)
      if path.end_with?('jsonlz4')
        File.open(path, 'wb') do |file|
          file.write(compress(string))
        end
      else
        File.open(path, 'w') do |file|
          file.write(string)
        end
      end
    end

    def self.decompress(string)
      string.force_encoding(Encoding::BINARY)
      size = string[8, 4].bytes.zip(OFFSETS.reverse).map do |byte, offset|
        byte * offset
      end.sum
      string = LZ4.block_decode(string[MOZ_PREFIX..-1])
      if string.bytesize != size
        raise "Expected size #{size} != #{string.bytesize}"
      end
      string.force_encoding(Encoding::UTF_8)
    end

    def self.compress(string)
      size = string.bytesize
      if size > MAX_SIZE
        raise FileTooLarge, 'Content over 4GB!'
      end
      sstr = OFFSETS.map do |offset|
        part = size / offset
        size %= offset
        part
      end.reverse.pack('c*')
      MOZ_ID + sstr + LZ4.block_encode(string)
    end
  end
end
