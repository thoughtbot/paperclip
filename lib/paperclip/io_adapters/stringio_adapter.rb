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
      original_filename ||= "data.#{extension_for(@content_type)}"
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

    def extension_for(content_type)
      type = MIME::Types[content_type].first
      type && type.extensions.first
    end

  end
end

Paperclip.io_adapters.register Paperclip::StringioAdapter do |target|
  StringIO === target
end
