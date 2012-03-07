require 'paperclip/callbacks'

module Paperclip
  module Glue
    def self.included base #:nodoc:
      base.extend ClassMethods
      base.send :include, Callbacks
      base.class_attribute :attachment_definitions
    end
  end
end
