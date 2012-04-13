module Paperclip
  class SinatraFileAdapter
    def initialize(target)
      @target = target

      @tempfile = @target[:tempfile]
    end

    def original_filename
      @target[:filename]
    end

    def content_type
      @target[:type]
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
  end
end

Paperclip.io_adapters.register Paperclip::SinatraFileAdapter do |target|
  target.class == Hash && !target[:tempfile].nil? && (File === target[:tempfile] || Tempfile === target[:tempfile]) 
end
