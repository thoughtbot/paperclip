module Paperclip
  class ContentTypeDetector
    EMPTY_TYPE = "inode/x-empty"
    SENSIBLE_DEFAULT = "application/octet-stream"

    def initialize(filename)
      @filename = filename
    end

    def detect
      if blank?
        SENSIBLE_DEFAULT
      elsif empty?
        EMPTY_TYPE
      elsif !match?
        type_from_file_command
      elsif !multiple?
        possible_types.first
      else
        best_type_match
      end.to_s
    end

    private

    def empty?
      File.exists?(@filename) && File.size(@filename) == 0
    end

    def blank?
      @filename.nil? || @filename.empty?
    end

    def possible_types
      @possible_types ||= MIME::Types.type_for(@filename)
    end

    def match?
      possible_types.length > 0
    end

    def multiple?
      possible_types.length > 1
    end

    def best_type_match
      types_matching_file = possible_types.select {|type| type.content_type == type_from_file_command}
      official_types = possible_types.reject {|type| type.content_type.match(/\/x-/) }
      (types_matching_file.first || official_types.first || possible_types.first).content_type
    end

    def type_from_file_command
      @type_from_file_command ||= FileCommandContentTypeDetector.new(@filename).detect
    end

  end
end
