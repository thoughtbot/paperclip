module Paperclip
  class IdentityAdapter < AbstractAdapter
    def initialize
    end

    def new(target, _)
      target
    end
  end
end

Paperclip.io_adapters.register Paperclip::IdentityAdapter.new do |target|
  Paperclip.io_adapters.registered?(target)
end

