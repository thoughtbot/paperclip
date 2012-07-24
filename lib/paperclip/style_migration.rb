require 'active_support/inflector'

module Paperclip
  class StyleMigration
    def self.run(table_name, attachment_name, *style_info)
      new(model_class(table_name), attachment_name).run(*style_info)
    end

    def initialize(model_class, attachment_name)
      @model_class = model_class
      @attachment_name = attachment_name
    end

    protected

    def self.model_class(table_name)
      model_class_name = table_name.to_s.singularize.camelize
      begin
        model_class_name.constantize
      rescue NameError
        raise ArgumentError, "found no model named #{model_class_name}"
      end
    end

    def each_attachment(&block)
      @model_class.find_each do |model|
        block.call(attachment_for(model))
      end
    end

    def attachment_for(model)
      begin
        model.send(@attachment_name)
      rescue NoMethodError
        raise ArgumentError, "found no attachment named #{@attachment_name} on #{model}"
      end
    end
  end
end
