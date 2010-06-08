module Paperclip
  # Handles thumbnailing images that are uploaded.
  class Thumbnail < Processor

    attr_accessor :current_geometry, :target_geometry, :format, :whiny, :convert_options, :source_file_options

    # Creates a Thumbnail object set to work on the +file+ given. It
    # will attempt to transform the image into one defined by +target_geometry+
    # which is a "WxH"-style string. +format+ will be inferred from the +file+
    # unless specified. Thumbnail creation will raise no errors unless
    # +whiny+ is true (which it is, by default. If +convert_options+ is
    # set, the options will be appended to the convert command upon image conversion
    def initialize file, options = {}, attachment = nil
      super

      geometry             = options[:geometry]
      @file                = file
      @crop                = geometry[-1,1] == '#'
      @target_geometry     = Geometry.parse geometry
      @current_geometry    = Geometry.from_file @file
      @source_file_options = options[:source_file_options]
      @convert_options     = options[:convert_options]
      @whiny               = options[:whiny].nil? ? true : options[:whiny]
      @format              = options[:format]

      @source_file_options = @source_file_options.split(/\s+/) if @source_file_options.respond_to?(:split)
      @convert_options     = @convert_options.split(/\s+/)     if @convert_options.respond_to?(:split)

      @current_format      = File.extname(@file.path)
      @basename            = File.basename(@file.path, @current_format)

    end

    # Returns true if the +target_geometry+ is meant to crop.
    def crop?
      @crop
    end

    # Returns true if the image is meant to make use of additional convert options.
    def convert_options?
      !@convert_options.nil? && !@convert_options.empty?
    end

    # Performs the conversion of the +file+ into a thumbnail. Returns the Tempfile
    # that contains the new image.
    def make
      src = @file
      dst = Tempfile.new([@basename, @format].compact.join("."))
      dst.binmode

      begin
        options = [
          source_file_options,
          "#{ File.expand_path(src.path) }[0]",
          transformation_command,
          convert_options,
          "#{ File.expand_path(dst.path) }"
        ].flatten.compact

        success = Paperclip.run("convert", *options)
      rescue PaperclipCommandLineError => e
        raise PaperclipError, "There was an error processing the thumbnail for #{@basename}" if @whiny
      end

      dst
    end

    # Returns the command ImageMagick's +convert+ needs to transform the image
    # into the thumbnail.
    def transformation_command
      scale, crop = @current_geometry.transformation_to(@target_geometry, crop?)
      trans = []
      trans << "-resize" << scale unless scale.nil? || scale.empty?
      trans << "-crop" << crop << "+repage" if crop
      trans
    end
  end
end
