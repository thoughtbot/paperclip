require 'active_support/inflector'

class StyleAdder
  def self.run(table_name, attachment_name, styles)
    new(model_class(table_name), attachment_name, styles).run
  end

  def initialize(model_class, attachment_name, styles)
    @model_class = model_class
    @attachment_name = attachment_name
    @styles = styles
  end

  def run
    p @model_class
    p @model_class.all
    @model_class.find_each do |model|
      attachment = model.send(@attachment_name)

      file = Paperclip.io_adapters.for(attachment)
      attachment.instance_variable_set('@queued_for_write', {:original => file})

      attachment.send(:post_process, *@styles.keys)

      model.save
    end
  end

  private

  def self.model_class(table_name)
    model_class_name = table_name.to_s.singularize.camelize
    begin
      model_class_name.constantize
    rescue NameError
      p "here"
      raise ArgumentError, "found no model named #{model_class_name}"
    end
  end
end
