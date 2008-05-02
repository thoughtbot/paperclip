module Paperclip
  # The Upfile module is a convenience module for adding uploaded-file-type methods
  # to the +File+ class. Useful for testing.
  #   user.avatar = File.new("test/test_avatar.jpg")
  module Upfile

    # Infer the MIME-type of the file from the extension.
    def content_type
      type = self.path.match(/\.(\w+)$/)[1] rescue "octet-stream"
      case type
      when "jpg", "png", "gif" then "image/#{type}"
      when "txt" then "text/plain"
      when "csv", "xml", "html", "htm", "css", "js" then "text/#{type}"
      else "x-application/#{type}"
      end
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

class File #:nodoc:
  include Paperclip::Upfile
end
