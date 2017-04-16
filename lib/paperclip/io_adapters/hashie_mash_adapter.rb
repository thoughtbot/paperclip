module Paperclip
  class HashieMashAdapter < AbstractAdapter

    def initialize(target)
      self.original_filename = target.filename
      @tempfile = copy_to_tempfile(target.tempfile)
      @content_type = ContentTypeDetector.new(@tempfile.path).detect
      @size = @tempfile.size
    end

  end
end

Paperclip.io_adapters.register Paperclip::HashieMashAdapter do |target|
  target.class.name.include?("Hashie::Mash")
end
