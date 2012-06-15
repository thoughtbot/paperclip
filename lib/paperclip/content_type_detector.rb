module Paperclip
  class ContentTypeDetector
    def initialize(filename)
      @filename = filename
    end

    def detect
      if !match?
        type_from_file_command
      elsif !multiple?
        possible_types.first
      else
        best_type_match
      end.to_s
    end

    private

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
      official_types = possible_types.reject {|type| type.content_type.match(/\/x-/) }
      (official_types.first || possible_types.first).content_type
    end

    def type_from_file_command
      # On BSDs, `file` doesn't give a result code of 1 if the file doesn't exist.
      type = Paperclip.run("file", "-b --mime :file", :file => @filename)
      if type.match(/\(.*?\)/)
        type = "application/octet-stream"
      end
      type.split(/[:;\s]+/)[0]
    end

  end
end
