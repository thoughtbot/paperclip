module Paperclip
  class DataUriAdapter < StringioAdapter

    REGEXP = /^data:([-\w]+\/[-\w\+]+);base64,(.*)/

    def initialize(target)
      @data_uri_parts = target.match(REGEXP) || []
      deserialize
      cache_current_values
      @tempfile = copy_to_tempfile
    end

    private

    def cache_current_values
      self.original_filename = 'base64.txt'

      @content_type = @data_uri_parts[1]
      @content_type ||= 'text/plain'

      @size = @target.size
    end

    def deserialize
      @target = StringIO.new(Base64.decode64(@data_uri_parts[2]))
    end

  end
end

Paperclip.io_adapters.register Paperclip::DataUriAdapter do |target|
  String === target && target =~ Paperclip::DataUriAdapter::REGEXP
end
