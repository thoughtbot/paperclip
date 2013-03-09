module Paperclip
  class ContentTypeDetector
    # The content-type detection strategy is as follows:
    #
    # 1. Blank/Empty files: If there's no filename or the file is empty, provide a sensible default
    #    (application/octet-stream or inode/x-empty)
    #
    # 2. Uploaded file: Use the uploaded file's content type if it is in the list of mime-types
    #    for the file's extension
    #
    # 3. Standard types: Return the first standard (without an x- prefix) entry in the list of
    #    mime-types
    #
    # 4. Experimental types: If there were no standard types in the mime-types list, try to return
    #    the first experimental one
    #
    # 5. Unrecognized extension: Use the file's content type or a sensible default if there are
    #    no entries in mime-types for the extension
    #
    
    EMPTY_TYPE = "inode/x-empty"
    SENSIBLE_DEFAULT = "application/octet-stream"

    def initialize(filename)
      @filename = filename
    end

    # Returns a String describing the file's content type
    def detect
      if blank_name?
        SENSIBLE_DEFAULT
      elsif empty_file?
        EMPTY_TYPE
      elsif types_matching_file.any?
        types_matching_file.first
      elsif official_types.any?
        official_types.first
      elsif possible_types.any?
        possible_types.first
      else
        type_from_file_command || SENSIBLE_DEFAULT
      end.to_s
    end

    private

    def empty_file?
      File.exists?(@filename) && File.size(@filename) == 0
    end

    def blank_name?
      @filename.nil? || @filename.empty?
    end
    
    def empty?
      File.exists?(@filename) && File.size(@filename) == 0
    end

    def possible_types
      MIME::Types.type_for(@filename).collect(&:content_type)
    end
    
    def official_types
      possible_types.reject{|content_type| content_type.match(/\/x-/) }
    end
    
    def types_matching_file
      possible_types.select{|content_type| content_type == type_from_file_command}
    end

    def type_from_file_command
      FileCommandContentTypeDetector.new(@filename).detect
    end
  end
end
