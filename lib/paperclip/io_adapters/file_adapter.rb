module Paperclip
  class FileAdapter < AbstractAdapter
    def initialize(target)
      @target = target
      cache_current_values
    end

    private

    def cache_current_values
      @original_filename = @target.original_filename if @target.respond_to?(:original_filename)
      @original_filename ||= File.basename(@target.path)
      @tempfile = copy_to_tempfile(@target)
      @content_type = calculate_content_type
      @size = File.size(@target)
    end

    def calculate_content_type
      types = MIME::Types.type_for(original_filename)
      if types.length == 0
        type_from_file_command
      elsif types.length == 1
        types.first.content_type
      else
        best_content_type_option(types)
      end
    end
  end
end

Paperclip.io_adapters.register Paperclip::FileAdapter do |target|
  File === target || Tempfile === target
end
