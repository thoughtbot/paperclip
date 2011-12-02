module Paperclip
  class AttachmentAdapter

    def initialize(target)
      @target = target
      cache_current_values
    end

    def original_filename
      @original_filename
    end

    def content_type
      @content_type
    end

    def size
      @size
    end

    def nil?
      false
    end

    def fingerprint
      @fingerprint ||= Digest::MD5.file(path).to_s
    end

    def read(length = nil, buffer = nil)
      @tempfile.read(length, buffer)
    end

    def eof?
      @tempfile.eof?
    end

    def path
      @tempfile.path
    end

    private

    def cache_current_values
      @tempfile = copy_to_tempfile(@target)
      @original_filename = @target.original_filename
      @content_type = @target.content_type
      @size = @tempfile.size || @target.size
    end

    def copy_to_tempfile(src)
      dest = Tempfile.new(src.original_filename)
      FileUtils.cp(src.path(:original), dest.path)
      dest
    end

  end
end

Paperclip.io_adapters.register Paperclip::AttachmentAdapter do |target|
  Paperclip::Attachment === target
end
