module Paperclip
  class TempfileFactory

    ILLEGAL_FILENAME_CHARACTERS = /^~/
    ILLEGAL_EXTENSION_CHARACTERS = /:/

    def generate(name)
      @name = name
      file = Tempfile.new([basename, extension])
      file.binmode
      file
    end

    def extension
      File.extname(@name).gsub(ILLEGAL_EXTENSION_CHARACTERS, '_')
    end

    def basename
      File.basename(@name, File.extname(@name)).gsub(ILLEGAL_FILENAME_CHARACTERS, '_')
    end
  end
end