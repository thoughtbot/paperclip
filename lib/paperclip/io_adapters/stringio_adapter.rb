module Paperclip
  class StringioAdapter < AbstractAdapter
    def initialize(target)
      @target = target
      @tempfile = copy_to_tempfile
      cache_current_values
    end

    attr_writer :content_type

    private

    def cache_current_values
      @content_type = ContentTypeDetector.new(@tempfile.path).detect
      original_filename = @target.original_filename if @target.respond_to?(:original_filename)
      original_filename ||= "data"
      self.original_filename = original_filename.strip
      @size = @target.size
    end

    def copy_to_tempfile
      while data = @target.read(16*1024)
        destination.write(data)
      end
      destination.rewind
      destination
    end

  end
end

Paperclip.io_adapters.register Paperclip::StringioAdapter do |target|
  StringIO === target
end
