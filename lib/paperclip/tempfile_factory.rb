module Paperclip
  class TempfileFactory

    ILLEGAL_FILENAME_CHARACTERS = /^~/

    def generate(name)
      @name = name
      Tempfile.new([basename, extension]).tap &:binmode
    end

    def extension
      File.extname(@name)
    end

    def basename
      SecureRandom.hex(16).encode('UTF-8')
    end
  end
end
