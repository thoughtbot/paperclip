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

    def major_version_of_file_command
      output = /^file-(\d+)\./.match(Paperclip.run("file", "-v 2>&1", {}, expected_outcodes: [0,1]))
      output && output.size > 1 ? output[1] : nil
    end

    def type_from_file_command
      type = begin
        command_version = major_version_of_file_command
        mime_option = command_version && command_version.to_i <= 4 ? '-i' : '--mime'
        # On BSDs, `file` doesn't give a result code of 1 if the file doesn't exist.
        Paperclip.run("file", "-b #{mime_option} :file", :file => @filename)
      rescue Cocaine::CommandLineError => e
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

