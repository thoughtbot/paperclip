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
    #   :log_command -> Log the command being run when set to true (defaults to false).
    #                   This will only log if logging in general is set to true as well.
    #
    #   :swallow_stderr -> Set to true if you don't care what happens on STDERR.
    #
    def run(cmd, arguments = "", local_options = {})
      command_path = options[:command_path]
      Cocaine::CommandLine.path = ( Cocaine::CommandLine.path ? [Cocaine::CommandLine.path].flatten | [command_path] : command_path )
      local_options = local_options.merge(:logger => logger) if logging? && (options[:log_command] || local_options[:log_command])
      Cocaine::CommandLine.new(cmd, arguments, local_options).run
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
        klass.const_defined?(partial_class_name) ? klass.const_get(partial_class_name, false) : klass.const_missing(partial_class_name)
      end
    end

    def check_for_url_clash(name,url,klass)
      @names_url ||= {}
      default_url = url || Attachment.default_options[:url]
      if @names_url[name] && @names_url[name][:url] == default_url && @names_url[name][:class] != klass && @names_url[name][:url] !~ /:class/
        log("Duplicate URL for #{name} with #{default_url}. This will clash with attachment defined in #{@names_url[name][:class]} class")
      end
      @names_url[name] = {:url => default_url, :class => klass}
    end

    def reset_duplicate_clash_check!
      @names_url = nil
    end
  end
end
