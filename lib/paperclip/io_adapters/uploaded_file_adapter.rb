module Paperclip
  class UploadedFileAdapter < AbstractAdapter
    def initialize(target)
      @target = target
      cache_current_values

      if @target.respond_to?(:tempfile)
        @tempfile = copy_to_tempfile(@target.tempfile)
      else
        @tempfile = copy_to_tempfile(@target)
      end
    end

    private

    def cache_current_values
      @original_filename = @target.original_filename
      @content_type = @target.content_type.to_s.strip
      @size = File.size(@target.path)
    end
  end
end

Paperclip.io_adapters.register Paperclip::UploadedFileAdapter do |target|
  target.class.name.include?("UploadedFile")
end
