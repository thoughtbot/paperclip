require 'active_support/inflector'

module Paperclip
  class StyleMigration
    def self.run(model_enumerator, attachment_name, *style_info)
      new(model_enumerator, attachment_name).run(*style_info)
    end

    def initialize(model_enumerator, attachment_name)
      @model_enumerator = model_enumerator
      @attachment_name = attachment_name
    end

    protected

    def each_attachment(&block)
      @model_enumerator.each do |model|
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
