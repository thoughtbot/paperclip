module Thoughtbot
  module Paperclip
    # The Upfile module is a convenience module for adding uploaded-file-looking methods
    # to the +File+ class. Useful for testing.
    #   f = File.new("test/test_avatar.jpg")
    #   f.original_filename    # => "test_avatar.jpg"
    #   f.content_type         # => "image/jpg"
    #   user.avatar = f
    module Upfile
      # Infer the MIME-type of the file from the extension.
      def content_type
        type = self.path.match(/\.(\w+)$/)[1]
        case type
        when "jpg", "png", "gif" then "image/#{type}"
        when "txt", "csv", "xml", "html", "htm" then "text/#{type}"
        else "x-application/#{type}"
        end
      end

      # Returns the file's normal name.
      def original_filename
        self.path
      end

      # Returns the size of the file.
      def size
        File.size(self)
      end
    end
  end
end

File.send(:include, Thoughtbot::Paperclip::Upfile)