module Paperclip
  class StringioAdapter
    def initialize(target)
      @target = target
      @tempfile = copy_to_tempfile(@target)
    end

    attr_writer :original_filename, :content_type

    def original_filename
      @original_filename ||= @target.original_filename if @target.respond_to?(:original_filename)
      @original_filename ||= "stringio.txt"
      @original_filename.strip
    end

    def content_type
      @content_type ||= @target.content_type if @target.respond_to?(:content_type)
      @content_type ||= "text/plain"
      @content_type
    end

    def size
      @target.size
    end

    def fingerprint
      Digest::MD5.hexdigest(read)
    end

    def read(length = nil, buffer = nil)
      @tempfile.read(length, buffer)
    end

    # We don't use this directly, but aws/sdk does.
    def rewind
      @tempfile.rewind
    end

    def eof?
      @tempfile.eof?
    end

    def path
      @tempfile.path
    end

    private

    def copy_to_tempfile(src)
      extension = File.extname(original_filename)
      basename = File.basename(original_filename, extension)
      dest = Tempfile.new([basename, extension])
      dest.binmode
      while data = src.read(16*1024)
        dest.write(data)
      end
      dest.rewind
      dest
    end

  end
end

Paperclip.io_adapters.register Paperclip::StringioAdapter do |target|
  StringIO === target
end
