require 'paperclip'

module Paperclip
  if defined? Rails::Railtie
    require 'rails'
    class Railtie < Rails::Railtie
      config.after_initialize do
        Paperclip::Railtie.insert
      end
    end
  end

  class Railtie
    def self.insert
      ActiveRecord::Base.send(:include, Paperclip)
      File.send(:include, Paperclip::Upfile)
      ActionController::Base.send(:include, Paperclip::Storage::Database::ControllerClassMethods)
    end
  end
end

