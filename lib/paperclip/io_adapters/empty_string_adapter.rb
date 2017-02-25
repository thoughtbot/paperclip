module Paperclip
  class EmptyStringAdapter < AbstractAdapter
    def nil?
      false
    end

    def assignment?
      false
    end
  end
end

Paperclip.io_adapters.register Paperclip::EmptyStringAdapter do |target|
  target.is_a?(String) && target.empty?
end
