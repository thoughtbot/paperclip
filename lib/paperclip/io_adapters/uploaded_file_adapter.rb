module Paperclip
  # The UploadedFileAdapter class is responsible for processing files that were
  # uploaded by a HTTP client (UploadedFile).
  class UploadedFileAdapter < AbstractAdapter
    # Available options:
    #
    # +trust_mime_type+ (default: true) - Whether to trust the Content-Type sent by the uploading client
    # (browser in most cases). If set to +false+, the MIME type will be detected by ContentTypeDetector
    def self.options
      @options ||= {
        :trust_mime_type => true
      }
    end

    def initialize(target)
      @options = self.class.options

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
      @content_type = @options[:trust_mime_type] ?
        @target.content_type.to_s.strip :
        ContentTypeDetector.new(@target.path).detect
      @size = File.size(@target.path)
    end
  end
end

Paperclip.io_adapters.register Paperclip::UploadedFileAdapter do |target|
  target.class.name.include?("UploadedFile")
end
