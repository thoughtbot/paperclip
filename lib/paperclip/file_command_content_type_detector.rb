module Paperclip
  class FileCommandContentTypeDetector
    SENSIBLE_DEFAULT = "application/octet-stream"

    def initialize(filename)
      @filename = filename
    end

    def detect
      type_from_file_command
    end

    private

    def type_from_file_command
      type = begin
        MimeMagic.by_magic(File.open(@filename)).try(:type) ||
          Paperclip.run("file", "-b --mime :file", :file => @filename)
      rescue Errno::ENOENT => e
        Paperclip.log("Error while determining content type: #{e}")
        SENSIBLE_DEFAULT
      end

      if type.nil? || type.match(/\(.*?\)/)
        type = SENSIBLE_DEFAULT
      end
      type.split(/[:;\s]+/)[0]
    end

  end
end
