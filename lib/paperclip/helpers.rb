module Paperclip
  module Helpers
    def configure
      yield(self) if block_given?
    end

    def interpolates key, &block
      Paperclip::Interpolations[key] = block
    end

    # The run method takes the name of a binary to run, the arguments to that binary
    # and some options:
    #
    #   :command_path -> A $PATH-like variable that defines where to look for the binary
    #                    on the filesystem. Colon-separated, just like $PATH.
    #
    #   :expected_outcodes -> An array of integers that defines the expected exit codes
    #                         of the binary. Defaults to [0].
    #
    #   :log_command -> Log the command being run when set to true (defaults to true).
    #                   This will only log if logging in general is set to true as well.
    #
    #   :swallow_stderr -> Set to true if you don't care what happens on STDERR.
    #
    def run(cmd, arguments = "", interpolation_values = {}, local_options = {})
      command_path = options[:command_path]
      Cocaine::CommandLine.path = [Cocaine::CommandLine.path, command_path].flatten.compact.uniq
      if logging? && (options[:log_command] || local_options[:log_command])
        local_options = local_options.merge(:logger => logger)
      end
      Cocaine::CommandLine.new(cmd, arguments, local_options).run(interpolation_values)
    end

    # Find all instances of the given Active Record model +klass+ with attachment +name+.
    # This method is used by the refresh rake tasks.
    def each_instance_with_attachment(klass, name)
      class_for(klass).unscoped.where("#{name}_file_name IS NOT NULL").find_each do |instance|
        yield(instance)
      end
    end

    def class_for(class_name)
      class_name.split('::').inject(Object) do |klass, partial_class_name|
        if klass.const_defined?(partial_class_name)
          klass.const_get(partial_class_name, false)
        else
          klass.const_missing(partial_class_name)
        end
      end
    end

    def reset_duplicate_clash_check!
      @names_url = nil
    end
  end
end
