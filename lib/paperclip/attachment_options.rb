module Paperclip
  class AttachmentOptions < Hash
    def initialize(options)
      if options.is_a? Symbol
        options = options == :default ? {} : Attachment.options_for(options)
      end
      options.each do |k, v|
        self.[]=(k, v)
      end
    end
  end
end
