module Paperclip
  class UrlAdapter < UriAdapter

    REGEXP = /^https?:\/\//

    def initialize(target)
      super(URI(target))
    end

  end
end

Paperclip.io_adapters.register Paperclip::UrlAdapter do |target|
  String === target && target =~ Paperclip::UrlAdapter::REGEXP
end
