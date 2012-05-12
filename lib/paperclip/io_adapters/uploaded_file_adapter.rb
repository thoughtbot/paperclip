module Paperclip
  class UploadedFileAdapter
    def initialize(target)
      @target = target

      if @target.respond_to?(:tempfile)
        @tempfile = copy_to_tempfile(@target.tempfile)
      else
        @tempfile = copy_to_tempfile(@target)
      end
    end

    def original_filename
      @target.original_filename
    end

    def content_type
      @target.content_type
    end

    def fingerprint
      @fingerprint ||= Digest::MD5.file(path).to_s
    end

    def size
      File.size(path)
    end

    def nil?
      false
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
      FileUtils.cp(src.path, dest.path)
      dest
    end
  end
end

Paperclip.io_adapters.register Paperclip::UploadedFileAdapter do |target|
  target.class.name.include?("UploadedFile")
end
