module Paperclip
  class IdentityAdapter < AbstractAdapter
    def new(adapter)
      adapter
    end
  end
end

Paperclip.io_adapters.register Paperclip::IdentityAdapter.new do |target|
  Paperclip.io_adapters.registered?(target)
end

