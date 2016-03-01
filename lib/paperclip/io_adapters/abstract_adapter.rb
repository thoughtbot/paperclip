require 'active_support/core_ext/module/delegation'

module Paperclip
  class AbstractAdapter
    OS_RESTRICTED_CHARACTERS = %r{[/:]}

    attr_reader :content_type, :original_filename, :size
    delegate :binmode, :binmode?, :close, :close!, :closed?, :eof?, :path, :rewind, :unlink, :to => :@tempfile
    alias :length :size

    def fingerprint
      @fingerprint ||= Digest::MD5.file(path).to_s
    end

    def read(length = nil, buffer = nil)
      @tempfile.read(length, buffer)
    end

    def inspect
      "#{self.class}: #{self.original_filename}"
    end

    def original_filename=(new_filename)
      return unless new_filename
      @original_filename = new_filename.gsub(OS_RESTRICTED_CHARACTERS, "_")
    end

    def nil?
      false
    end

    def assignment?
      true
    end

    private

    def destination
      @destination ||= TempfileFactory.new.generate(@original_filename.to_s)
    end

    def copy_to_tempfile(src)
      link_or_copy_file(src.path, destination.path)
      destination
    end

    def link_or_copy_file(src, dest)
      Paperclip.log("Trying to link #{src} to #{dest}")
      FileUtils.ln(src, dest, force: true) # overwrite existing
      @destination.close
      @destination.open.binmode
    rescue Errno::EXDEV, Errno::EPERM, Errno::ENOENT => e
      Paperclip.log("Link failed with #{e.message}; copying link #{src} to #{dest}")
      FileUtils.cp(src, dest)
    end
  end
end
