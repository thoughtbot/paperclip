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
    @model_class.find_each do |model|
      attachment = attachment_for(model)

      file = Paperclip.io_adapters.for(attachment)
      attachment.instance_variable_set('@queued_for_write', {:original => file})

      attachment.send(:post_process, *styles_for(attachment))

      model.save
    end
  end

  private

  def self.model_class(table_name)
    model_class_name = table_name.to_s.singularize.camelize
    begin
      model_class_name.constantize
    rescue NameError
      raise ArgumentError, "found no model named #{model_class_name}"
    end
  end

  def attachment_for(model)
    begin
      model.send(@attachment_name)
    rescue NoMethodError
      raise ArgumentError, "found no attachment named #{@attachment_name} on #{model}"
    end
  end

  def styles_for(attachment)
    expected_styles = attachment.send(:styles).keys
    if subset?(@styles.keys, expected_styles)
      @styles.keys
    else
      raise ArgumentError, "unsupported styles; excepted any of #{expected_styles}"
    end
  end

  def subset?(smaller, larger)
    (smaller - larger).empty?
  end
end
