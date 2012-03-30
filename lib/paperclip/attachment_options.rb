module Paperclip
  class AttachmentOptions < Hash
    def initialize(options)
      options.each do |k, v|
        self.[]=(k, v)
      end
    end
  end
end
