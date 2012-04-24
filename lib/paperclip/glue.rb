require 'paperclip/callbacks'
require 'paperclip/validators'
require 'paperclip/schema'

module Paperclip
  module Glue
    def self.included base #:nodoc:
      base.extend ClassMethods
      base.send :include, Callbacks
      base.send :include, Validators
      base.class_attribute :attachment_definitions

      if defined?(ActiveRecord)
        ActiveRecord::ConnectionAdapters::AbstractAdapter.send(:include, Paperclip::Schema)
        ActiveRecord::ConnectionAdapters::Table.send(:include, Paperclip::Schema)
        ActiveRecord::ConnectionAdapters::TableDefinition.send(:include, Paperclip::Schema)
      end

      locale_path = Dir.glob(File.dirname(__FILE__) + "/locales/*.{rb,yml}")
      I18n.load_path += locale_path unless I18n.load_path.include?(locale_path)
    end
  end
end
