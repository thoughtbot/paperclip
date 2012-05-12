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

    def cache_current_values
      @tempfile = copy_to_tempfile(@target)
      @original_filename = @target.original_filename
      @content_type = @target.content_type
      @size = @tempfile.size || @target.size
    end

    def copy_to_tempfile(src)
      extension = File.extname(src.original_filename)
      basename = File.basename(src.original_filename, extension)
      dest = Tempfile.new([basename, extension])
      dest.binmode
      if src.respond_to? :copy_to_local_file
        src.copy_to_local_file(:original, dest.path)
      else
        FileUtils.cp(src.path(:original), dest.path)
      end
      dest
    end
  end
end

Paperclip.io_adapters.register Paperclip::AttachmentAdapter do |target|
  Paperclip::Attachment === target
end
