require "digest"
require "file_wrapper"

module Paperclip
  # The Upfile module is a convenience module for adding uploaded-file-type methods
  # to the +File+ class. Useful for testing.
  #   user.avatar = File.new("test/test_avatar.jpg")
  module Upfile

    # Infer the MIME-type of the file from it's "magic".
    def content_type
      FileWrapper.get_mime(self.path) || "application/octet-stream"
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
    attr_accessor :original_filename, :content_type, :fingerprint,
      :file_md5_hexdigest, :file_rmd160_hexdigest, :file_sha1_hexdigest, :file_sha256_hexdigest,
      :file_sha384_hexdigest, :file_sha512_hexdigest, :file_tiger_hexdigest, :file_whirlpool_hexdigest
    def original_filename
      @original_filename ||= "stringio.txt"
    end
    def content_type
      @content_type ||= "text/plain"
    end
    def fingerprint
      @fingerprint ||= Digest::MD5.hexdigest(self.string)
    end
    def file_md5_hexdigest
      @file_md5_hexdigest ||= Digest::MD5.hexdigest(self.string)
    end
    def file_rmd160_hexdigest
      @file_rmd160_hexdigest ||= Digest::RMD160.hexdigest(self.string)
    end
    def file_sha1_hexdigest
      @file_sha1_hexdigest ||= Digest::SHA1.hexdigest(self.string)
    end
    def file_sha256_hexdigest
      @file_sha256_hexdigest ||= Digest::SHA256.hexdigest(self.string)
    end
    def file_sha384_hexdigest
      @file_sha384_hexdigest ||= Digest::SHA384.hexdigest(self.string)
    end
    def file_sha512_hexdigest
      @file_sha512_hexdigest ||= Digest::SHA512.hexdigest(self.string)
    end
    def file_tiger_hexdigest
      @file_tiger_hexdigest ||= Digest::Tiger.hexdigest(self.string)
    end
    def file_whirlpool_hexdigest
      @file_whirlpool_hexdigest ||= Digest::Whirlpool.hexdigest(self.string)
    end
  end
end

class File #:nodoc:
  include Paperclip::Upfile
end
