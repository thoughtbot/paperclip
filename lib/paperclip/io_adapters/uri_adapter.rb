require 'open-uri'

module Paperclip
  class UriAdapter < AbstractAdapter
    def initialize(target)
      @target = target
      @content = download_content
      cache_current_values
      @tempfile = copy_to_tempfile(@content)
    end

    attr_writer :original_filename, :content_type
    private

    def download_content
      open(@target)
    end

    def cache_current_values
      @original_filename = @target.path.split("/").last
      @original_filename ||= "index.html"
      @original_filename = @original_filename.strip

      @content_type = @content.content_type if @content.respond_to?(:content_type)
      @content_type ||= "text/html"

      @size = @content.size
    end

    def copy_to_tempfile(src)
      while data = src.read(16*1024)
        destination.write(data)
      end
      destination.rewind
      destination
    end
  end
end

Paperclip.io_adapters.register Paperclip::UriAdapter do |target|
  target.kind_of?(URI)
end
