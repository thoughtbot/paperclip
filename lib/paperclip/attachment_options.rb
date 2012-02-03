module Paperclip
  class AttachmentOptions
    def initialize(options)
      @options = {:validations => []}.merge(options)
    end

    def [](key)
      @options[key]
    end

    def []=(key, value)
      @options[key] = value
    end

    def to_hash
      @options
    end
  end
end
