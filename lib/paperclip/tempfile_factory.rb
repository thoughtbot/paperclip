module Paperclip
  class TempfileFactory

    ILLEGAL_FILENAME_CHARACTERS = /^~/

    def generate(name)
      @name = name
      file = Tempfile.new([basename, extension])
      file.binmode
      file
    end

    def extension
      File.extname(@name)
    end

    def basename
      File.basename(@name, extension).gsub(ILLEGAL_FILENAME_CHARACTERS, '_')
    end
  end
end
