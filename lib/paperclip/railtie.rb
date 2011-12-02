require 'paperclip'
require 'paperclip/schema'

module Paperclip
  require 'rails'
  class Railtie < Rails::Railtie
    initializer 'paperclip.insert_into_active_record' do
      ActiveSupport.on_load :active_record do
        Paperclip::Railtie.insert
      end
    end
    rake_tasks do
      load "tasks/paperclip.rake"
    end
  end

  class Railtie
    def self.insert
      Paperclip.options[:logger] = Rails.logger if defined?(Rails)

      if defined?(ActiveRecord)
        Paperclip.options[:logger] = ActiveRecord::Base.logger
        ActiveRecord::Base.send(:include, Paperclip::Glue)
        ActiveRecord::ConnectionAdapters::AbstractAdapter.send(:include, Paperclip::Schema)
        ActiveRecord::ConnectionAdapters::Table.send(:include, Paperclip::Schema)
        ActiveRecord::ConnectionAdapters::TableDefinition.send(:include, Paperclip::Schema)
      end
    end
  end
end
