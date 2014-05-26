module RailsHelpers
  module ClassMethods
    def using_protected_attributes?
      ActiveRecord::VERSION::MAJOR < 4
    end
  end
end
