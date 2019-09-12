# frozen_string_literal: true

require_relative 'unpacker'

module BattleCatsRolls
  class PackReader < Struct.new(
    :list_path, :pack_path, :list_unpacker, :pack_unpacker, :name)

    include Enumerable

    def initialize new_list_path
      pathname = new_list_path[0...new_list_path.rindex('.')]

      super(
        new_list_path,
        "#{pathname}.pack",
        Unpacker.for_list,
        Unpacker.for_pack,
        File.basename(pathname))
    end

    def each
      if block_given?
        list_lines.each do |line|
          yield(*read(line))
        end
      else
        to_enum(__method__)
      end
    end

    def list_lines
      # Drop first line for number of files
      @list_lines ||= list_unpacker.decrypt(list_data).lines.drop(1)
    end

    def read line
      filename, offset, size = line.split(',')
      data = lambda do
        result = pack_unpacker.decrypt(pack_data[offset.to_i, size.to_i])

        if error = pack_unpacker.bad_data
          warn "! [#{error.class}:#{error.message}]" \
            " Failed decrypting #{filename} from #{pack_path}"
          exit(1)
        end

        result
      end

      [filename, data]
    end

    def read_eagerly line
      filename, data = read(line)

      [filename, data.call]
    end

    private

    def list_data
      @list_data ||= File.binread(list_path)
    end

    def pack_data
      @pack_data ||= File.binread(pack_path)
    end
  end
end
