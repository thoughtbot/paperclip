module Paperclip
  class DataUriAdapter < StringioAdapter

    REGEXP = /\Adata:([-\w]+\/[-\w\+]+);base64,(.*)/m

    def initialize(target_uri)
      @target_uri = target_uri
      cache_current_values
      @tempfile = copy_to_tempfile
    end

    private

    def cache_current_values
      self.original_filename = 'base64.txt'
      data_uri_parts ||= @target_uri.match(REGEXP) || []
      @content_type = data_uri_parts[1] || 'text/plain'
      @target = StringIO.new(Base64.decode64(data_uri_parts[2] || ''))
      @size = @target.size
    end

  end
end

Paperclip.io_adapters.register Paperclip::DataUriAdapter do |target|
  String === target && target =~ Paperclip::DataUriAdapter::REGEXP
end
