module Paperclip
  class FilePathAdapter < FileAdapter
    def initialize(target)
      super(File.new(target))
    end
  end
end

Paperclip.io_adapters.register Paperclip::FilePathAdapter do |target|
  String === target && File.file?(target)
end
