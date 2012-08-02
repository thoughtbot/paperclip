module Paperclip
  class NilAdapter < AbstractAdapter
    def initialize(target)
    end

    def original_filename
      ""
    end

    def content_type
      ""
    end

    def size
      0
    end

    def nil?
      true
    end

    def read(*args)
      nil
    end

    def eof?
      true
    end
  end
end

Paperclip.io_adapters.register Paperclip::NilAdapter do |target|
  target.nil? || ( (Paperclip::Attachment === target) && !target.present? )
end
