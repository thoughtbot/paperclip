module Paperclip
  class HttpUrlProxyAdapter < UriAdapter
    def self.register
      Paperclip.io_adapters.register self do |target|
        String === target && target =~ REGEXP
      end
    end

    REGEXP = /\Ahttps?:\/\//

    def initialize(target, options = {})
      already_escaped = CGI.unescape(target) != target
      escaped_target = if already_escaped
                         target
                       else
                         URI.escape(CGI.unescape(target))
                       end
      super(URI(escaped_target), options)
    end
  end
end
