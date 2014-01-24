module Paperclip
  class MediaTypeSpoofDetector
    def self.using(file, name)
      new(file, name)
    end

    def initialize(file, name)
      @file = file
      @name = name
    end

    def spoofed?
      if ! @name.blank?
        ! supplied_file_media_type.include?(calculated_media_type)
      end
    end

    private

    def supplied_file_media_type
      MIME::Types.type_for(@name).collect(&:media_type)
    end

    def calculated_media_type
      type_from_file_command.split("/").first
    end

    def type_from_file_command
      begin
        Paperclip.run("file", "-b --mime-type :file", :file => @file.path)
      rescue Cocaine::CommandLineError
        ""
      end
    end
  end
end
