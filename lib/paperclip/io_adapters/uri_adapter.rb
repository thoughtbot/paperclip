require "open-uri"

module Paperclip
  class UriAdapter < AbstractAdapter
    attr_writer :content_type

    def self.register
      Paperclip.io_adapters.register self do |target|
        target.is_a?(URI)
      end
    end

    def initialize(target, options = {})
      super
      @content = download_content
      cache_current_values
      @tempfile = copy_to_tempfile(@content)
    end

    private

    def cache_current_values
      self.content_type = content_type_from_content || "text/html"

      self.original_filename = filename_from_content_disposition ||
                               filename_from_path || default_filename
      @size = @content.size
    end

    def content_type_from_content
      @content.meta["content-type"].presence
    end

    def filename_from_content_disposition
      if @content.meta.key?("content-disposition") && @content.meta["content-disposition"].match(/filename/i)
        # can include both filename and filename* values according to RCF6266. filename should come first
        _, filename = @content.meta["content-disposition"].split(/filename\*?\s*=\s*/i)

        # filename can be enclosed in quotes or not
        matches = filename.match(/"(.*)"/)
        matches ? matches[1] : filename.split(';')[0]
      end
    end

    def filename_from_path
      @target.path.split("/").last
    end

    def default_filename
      "index.html"
    end

    def download_content
      options = { read_timeout: Paperclip.options[:read_timeout] }.compact

      URI.open(@target, **options)
    end

    def copy_to_tempfile(src)
      while data = src.read(16 * 1024)
        destination.write(data)
      end
      src.close
      destination.rewind
      destination
    end
  end
end
