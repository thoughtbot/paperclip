module Paperclip
  module Callbacks
    def self.included(base)
      base.extend(Defining)
      base.send(:include, Running)
    end

    module Defining
      def define_paperclip_callbacks(*callbacks)
        define_callbacks *[callbacks, {:terminator => "result == false"}].flatten
        callbacks.each do |callback|
          eval <<-end_callbacks
            def before_#{callback}(*args, &blk)
              set_callback(:#{callback}, :before, *args, &blk)
            end
            def after_#{callback}(*args, &blk)
              set_callback(:#{callback}, :after, *args, &blk)
            end
          end_callbacks
        end
      end
    end

    module Running
      def run_paperclip_callbacks(callback, opts = nil, &block)
        run_callbacks(callback, opts, &block)
      end
    end
  end
end
