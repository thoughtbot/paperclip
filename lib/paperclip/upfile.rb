require 'mime/types'

module Paperclip
  # The Upfile module is a convenience module for adding uploaded-file-type methods
  # to the +File+ class. Useful for testing.
  #   user.avatar = File.new("test/test_avatar.jpg")
  module Upfile
    # Infer the MIME-type of the file from the extension.
    def content_type
      type_from_file_command
    end

    def iterate_over_array_to_find_best_option(types)
      types.reject {|type| type.content_type.match(/\/x-/) }.first
    end

    def type_from_file_command
      #  On BSDs, `file` doesn't give a result code of 1 if the file doesn't exist.
      type = (self.original_filename.match(/\.(\w+)$/)[1] rescue "octet-stream").downcase
      mime_type = (Paperclip.run("file", "-b --mime :file", :file => self.path).split(/[:;]\s+/)[0] rescue "application/x-#{type}")
      mime_type = "application/x-#{type}" if mime_type.match(/\(.*?\)/)
      mime_type
    end

    # Returns the file's normal name.
    def original_filename
      File.basename(self.path)
    end

    # Returns the size of the file.
    def size
      File.size(self)
    end
  end
end

if defined? StringIO
  class StringIO
    attr_accessor :original_filename, :content_type, :fingerprint

    def original_filename
      @original_filename ||= "stringio.txt"
    end

    def content_type
      @content_type ||= "text/plain"
    end

    def fingerprint
      @fingerprint ||= Digest::MD5.hexdigest(self.string)
    end
  end
end

class File #:nodoc:
  include Paperclip::Upfile
end
