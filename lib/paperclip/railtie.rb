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

    rake_tasks { load "tasks/paperclip.rake" }
  end

  class Railtie
    def self.insert
      Paperclip.options[:logger] = Rails.logger

      if defined?(ActiveRecord)
        Paperclip.options[:logger] = ActiveRecord::Base.logger
        ActiveRecord::Base.send(:include, Paperclip::Glue)
      end
    end
  end
end
