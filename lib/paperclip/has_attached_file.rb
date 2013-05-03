module Paperclip
  class HasAttachedFile
    def self.define_on(klass, name, options)
      new(klass, name, options).define
    end

    def initialize(klass, name, options)
      @klass = klass
      @name = name
      @options = options
    end

    def define
      define_flush_errors
      define_getter
      define_setter
      define_query
      register_with_rake_tasks
      add_active_record_callbacks
    end

    private

    def define_flush_errors
      @klass.send(:validates_each, @name) do |record, attr, value|
        attachment = record.send(@name)
        attachment.send(:flush_errors)
      end
    end

    def define_getter
      name = @name
      options = @options

      @klass.send :define_method, @name do |*args|
        ivar = "@attachment_#{name}"
        attachment = instance_variable_get(ivar)

        if attachment.nil?
          attachment = Attachment.new(name, self, options)
          instance_variable_set(ivar, attachment)
        end

        if args.length > 0
          attachment.to_s(args.first)
        else
          attachment
        end
      end
    end

    def define_setter
      name = @name

      @klass.send :define_method, "#{@name}=" do |file|
        send(name).assign(file)
      end
    end

    def define_query
      name = @name

      @klass.send :define_method, "#{@name}?" do
        send(name).file?
      end
    end

    def register_with_rake_tasks
      Paperclip::Tasks::Attachments.add(@klass, @name, @options)
    end

    def add_active_record_callbacks
      name = @name
      @klass.send(:after_save) { send(name).send(:save) }
      @klass.send(:before_destroy) { send(name).send(:queue_all_for_delete) }
      @klass.send(:after_destroy) { send(name).send(:flush_deletes) }
    end
  end
end
