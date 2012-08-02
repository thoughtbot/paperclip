require 'active_support/core_ext/module/delegation'

module Paperclip
  class AbstractAdapter
    attr_reader :content_type, :original_filename, :size
    delegate :close, :closed?, :eof?, :path, :rewind, :unlink, :to => :@tempfile

    def fingerprint
      @fingerprint ||= Digest::MD5.file(path).to_s
    end

    def read(length = nil, buffer = nil)
      @tempfile.read(length, buffer)
    end

    def inspect
      "#{self.class}: #{self.original_filename}"
    end

    private

    def destination
      @destination ||= TempfileFactory.new.generate(original_filename)
    end

    def copy_to_tempfile(src)
      FileUtils.cp(src.path, destination.path)
      destination
    end
  end
end
