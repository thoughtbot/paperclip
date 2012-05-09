module Paperclip
  class AttachmentStyleAdapter
    def initialize(target)
      @target = target
      @attachment = target.attachment
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
      @tempfile = copy_to_tempfile(@attachment)
      @original_filename = @attachment.original_filename
      @content_type = @attachment.content_type
      @size = @tempfile.size || @attachment.size
    end

    def copy_to_tempfile(src)
      dest = Tempfile.new(src.original_filename)
      dest.binmode
      if src.respond_to? :copy_to_local_file
        src.copy_to_local_file(@target.name.to_s, dest.path)
      else
        FileUtils.cp(src.path(@target.name.to_s), dest.path)
      end
      dest
    end
  end
end

Paperclip.io_adapters.register Paperclip::AttachmentStyleAdapter do |target|
  Paperclip::Style === target
end
