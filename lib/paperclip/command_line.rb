module Paperclip
  class CommandLine
    class << self
      attr_accessor :path
    end

    def initialize(binary, params = "", options = {})
      @binary            = binary.dup
      @params            = params.dup
      @options           = options.dup
      @swallow_stderr    = @options.has_key?(:swallow_stderr) ? @options.delete(:swallow_stderr) : Paperclip.options[:swallow_stderr]
      @expected_outcodes = @options.delete(:expected_outcodes)
      @expected_outcodes ||= [0]
    end

    def command
      cmd = []
      cmd << full_path(@binary)
      cmd << interpolate(@params, @options)
      cmd << bit_bucket if @swallow_stderr
      cmd.join(" ")
    end

    def run
      Paperclip.log(command)
      begin
        output = self.class.send(:'`', command)
      rescue Errno::ENOENT
        raise Paperclip::CommandNotFoundError
      end
      if $?.exitstatus == 127
        raise Paperclip::CommandNotFoundError
      end
      unless @expected_outcodes.include?($?.exitstatus)
        raise Paperclip::PaperclipCommandLineError, "Command '#{command}' returned #{$?.exitstatus}. Expected #{@expected_outcodes.join(", ")}"
      end
      output
    end

    private

    def full_path(binary)
      [self.class.path, binary].compact.join("/")
    end

    def interpolate(pattern, vars)
      # interpolates :variables and :{variables}
      pattern.gsub(%r#:(?:\w+|\{\w+\})#) do |match|
        key = match[1..-1]
        key = key[1..-2] if key[0,1] == '{'
        if invalid_variables.include?(key)
          raise PaperclipCommandLineError,
            "Interpolation of #{key} isn't allowed."
        end
        shell_quote(vars[key.to_sym])
      end
    end

    def invalid_variables
      %w(expected_outcodes swallow_stderr)
    end

    def shell_quote(string)
      return "" if string.nil? or string.blank?
      if self.class.unix?
        string.split("'").map{|m| "'#{m}'" }.join("\\'")
      else
        %{"#{string}"}
      end
    end

    def bit_bucket
      self.class.unix? ? "2>/dev/null" : "2>NUL"
    end

    def self.unix?
      File.exist?("/dev/null")
    end
  end
end
