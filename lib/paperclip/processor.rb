module Paperclip
  # Paperclip processors allow you to modify attached files when they are
  # attached in any way you are able. Paperclip itself uses command-line
  # programs for its included Thumbnail processor, but custom processors
  # are not required to follow suit.
  #
  # Processors are required to be defined inside the Paperclip module and
  # are also required to be a subclass of Paperclip::Processor. There are
  # only two methods you must implement to properly be a subclass: 
  # #initialize and #make. Initialize's arguments are the file that will
  # be operated on (which is an instance of File), and a hash of options
  # that were defined in has_attached_file's style hash.
  #
  # All #make needs to do is return an instance of File (Tempfile is
  # acceptable) which contains the results of the processing.
  #
  # See Paperclip.run for more information about using command-line
  # utilities from within Processors.
  class Processor
    attr_accessor :file, :options

    def initialize file, options = {}
      @file = file
      @options = options
    end

    def make
    end

    def self.make file, options = {}
      new(file, options).make
    end
  end
  
  # Due to how ImageMagick handles its image format conversion and how Tempfile
  # handles its naming scheme, it is necessary to override how Tempfile makes
  # its names so as to allow for file extensions. Idea taken from the comments
  # on this blog post:
  # http://marsorange.com/archives/of-mogrify-ruby-tempfile-dynamic-class-definitions
  class Tempfile < ::Tempfile
    # Replaces Tempfile's +make_tmpname+ with one that honors file extensions.
    def make_tmpname(basename, n)
      extension = File.extname(basename)
      sprintf("%s,%d,%d%s", File.basename(basename, extension), $$, n, extension)
    end
  end
end
