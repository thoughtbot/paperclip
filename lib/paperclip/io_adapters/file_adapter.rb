module Paperclip
  class FileAdapter < AbstractAdapter
    def initialize(target)
      @target = target
      cache_current_values
    end

    private

    def cache_current_values
      filename = @target.original_filename if @target.respond_to?(:original_filename)
      filename ||= File.basename(@target.path)
      self.original_filename = filename.strip
      @tempfile = copy_to_tempfile(@target)
      @content_type = ContentTypeDetector.new(@target.path).detect
      @size = File.size(@target)
    end
  end
end

Paperclip.io_adapters.register Paperclip::FileAdapter do |target|
  File === target || Tempfile === target
end
