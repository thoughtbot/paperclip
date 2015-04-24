module Paperclip
  class IdentityAdapter < AbstractAdapter
    def new(adapter, _)
      adapter
    end

    def initialize
    end
  end
end

Paperclip.io_adapters.register Paperclip::IdentityAdapter.new do |target|
  Paperclip.io_adapters.registered?(target)
end

