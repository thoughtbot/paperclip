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
      define_getter
      define_setter
      define_query
    end

    private

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
  end
end
