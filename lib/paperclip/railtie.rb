require 'paperclip'

module Paperclip
  if defined? Rails::Railtie
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
  end

  class Railtie
    def self.insert
      ActiveRecord::Base.send(:include, Paperclip::Glue)
      File.send(:include, Paperclip::Upfile)
    end
  end
end
