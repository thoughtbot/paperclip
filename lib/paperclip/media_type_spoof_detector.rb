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
      if has_name? && has_extension? && media_type_mismatch? && mapping_override_mismatch?
        Paperclip.log("Content Type Spoof: Filename #{File.basename(@name)} (#{supplied_file_content_types}), content type discovered from file command: #{calculated_content_type}. See documentation to allow this combination.")
        true
      end
    end

    private

    def has_name?
      @name.present?
    end

    def has_extension?
      File.extname(@name).present?
    end

    def media_type_mismatch?
      ! supplied_file_media_types.include?(calculated_media_type)
    end

    def mapping_override_mismatch?
      mapped_content_type != calculated_content_type
    end

    def supplied_file_media_types
      @supplied_file_media_types ||= MIME::Types.type_for(@name).collect(&:media_type)
    end

    def calculated_media_type
      @calculated_media_type ||= calculated_content_type.split("/").first
    end

    def supplied_file_content_types
      @supplied_file_content_types ||= MIME::Types.type_for(@name).collect(&:content_type)
    end

    def calculated_content_type
      @calculated_content_type ||= type_from_file_command.chomp
    end

    def mapped_content_type
      Paperclip.options[:content_type_mappings][filename_extension]
    end

    def filename_extension
      File.extname(@name.to_s.downcase).sub(/^\./, '').to_sym
    end

    def type_from_file_command
      begin
        Paperclip.run("file", "-b --mime :file", :file => @file.path).split(/[:;]\s+/).first
      rescue Cocaine::CommandLineError
        ""
      end
    end
  end
end
