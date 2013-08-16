module Paperclip
  class HttpUrlProxyAdapter < UriAdapter

    REGEXP = /^https?:\/\//

    def initialize(target)
      super(URI(target))
    end

  end
end

Paperclip.io_adapters.register Paperclip::HttpUrlProxyAdapter do |target|
  String === target && target =~ Paperclip::HttpUrlProxyAdapter::REGEXP
end
