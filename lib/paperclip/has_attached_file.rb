module Paperclip
  class HasAttachedFile
    def initialize(name, options)
      @name = name
    end

    def define_on(klass)
      name = @name
      klass.send :define_method, "#{@name}=" do |file|
        send(name).assign(file)
      end
    end
  end
end
