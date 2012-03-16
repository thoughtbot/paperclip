module Paperclip
  # Paperclip processors allow you to modify attached files when they are
  # attached in any way you are able. Paperclip itself uses command-line
  # programs for its included Thumbnail processor, but custom processors
  # are not required to follow suit.
  #
  # Processors are required to be defined inside the Paperclip module and
  # are also required to be a subclass of Paperclip::Processor. There is
  # only one method you *must* implement to properly be a subclass:
  # #make, but #initialize may also be of use. Both methods accept 3
  # arguments: the file that will be operated on (which is an instance of
  # File), a hash of options that were defined in has_attached_file's
  # style hash, and the Paperclip::Attachment itself.
  #
  # All #make needs to return is an instance of File (Tempfile is
  # acceptable) which contains the results of the processing.
  #
  # See Paperclip.run for more information about using command-line
  # utilities from within Processors.
  class Processor
    attr_accessor :file, :options, :attachment

    def initialize file, options = {}, attachment = nil
      @file = file
      @options = options
      @attachment = attachment
    end

    def make
    end

    def self.make file, options = {}, attachment = nil
      new(file, options, attachment).make
    end
  end

  module ProcessorHelpers
    def processor(name) #:nodoc:
      @known_processors ||= {}
      if @known_processors[name.to_s]
        @known_processors[name.to_s]
      else
        name = name.to_s.camelize
        load_processor(name) unless Paperclip.const_defined?(name)
        processor = Paperclip.const_get(name)
        @known_processors[name.to_s] = processor
      end
    end

    def load_processor(name)
      if defined?(Rails.root) && Rails.root
        require File.expand_path(Rails.root.join("lib", "paperclip_processors", "#{name.underscore}.rb"))
      end
    end

    def clear_processors!
      @known_processors.try(:clear)
    end

    # You can add your own processor via the Paperclip configuration. Normally
    # Paperclip will load all processors from the
    # Rails.root/lib/paperclip_processors directory, but here you can add any
    # existing class using this mechanism.
    #
    #   Paperclip.configure do |c|
    #     c.register_processor :watermarker, WatermarkingProcessor.new
    #   end
    def register_processor(name, processor)
      @known_processors ||= {}
      @known_processors[name.to_s] = processor
    end
  end
end
