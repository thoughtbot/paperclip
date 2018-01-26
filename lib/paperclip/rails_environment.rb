module Paperclip
  class RailsEnvironment
    include Singleton

    def self.get
      instance.get
    end

    def self.version5?
      if instance.rails_exists?
        Rails.version.to_i == 5
      else
        false
      end
    end

    def get
      if rails_exists? && rails_environment_exists?
        Rails.env
      else
        nil
      end
    end

    def rails_exists?
      Object.const_defined?(:Rails)
    end

    def rails_environment_exists?
      Rails.respond_to?(:env)
    end
  end
end
