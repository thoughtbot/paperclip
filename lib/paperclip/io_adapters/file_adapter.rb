module Paperclip
  class FileAdapter < AbstractAdapter
    def initialize(target)
      @target = target
      @tempfile = copy_to_tempfile(@target)
    end

    def original_filename
      if @target.respond_to?(:original_filename)
        @target.original_filename
      else
        File.basename(@target.path)
      end
    end

    def content_type
      types = MIME::Types.type_for(original_filename)
      if types.length == 0
        type_from_file_command
      elsif types.length == 1
        types.first.content_type
      else
        best_content_type_option(types)
      end
    end

    def fingerprint
      @fingerprint ||= Digest::MD5.file(path).to_s
    end

    def size
      File.size(@tempfile)
    end

    def nil?
      @target.nil?
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
  end
end

Paperclip.io_adapters.register Paperclip::FileAdapter do |target|
  File === target || Tempfile === target
end
