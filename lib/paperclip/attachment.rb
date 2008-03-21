module Paperclip
  # The Attachment class manages the files for a given attachment. It saves when the model saves,
  # deletes when the model is destroyed, and processes the file upon assignment.
  class Attachment
    
    attr_reader :name, :instance, :file, :styles, :default_style

    # Creates an Attachment object. +name+ is the name of the attachment, +instance+ is the
    # ActiveRecord object instance it's attached to, and +options+ is the same as the hash
    # passed to +has_attached_file+.
    def initialize name, instance, options
      @name              = name
      @instance          = instance
      @url               = options[:url]           || 
                           "/:attachment/:id/:style/:basename.:extension"
      @path              = options[:path]          || 
                           ":rails_root/public/:attachment/:id/:style/:basename.:extension"
      @styles            = options[:styles]        || {}
      @default_url       = options[:default_url]   || "/:attachment/:style/missing.png"
      @validations       = options[:validations]   || []
      @default_style     = options[:default_style] || :original
      @queued_for_delete = []
      @processed_files   = {}
      @errors            = []
      @validation_errors = nil
      @dirty             = false

      normalize_style_definition

      @file              = File.new(path) if original_filename && File.exists?(path)
    end

    # What gets called when you call instance.attachment = File. It clears errors,
    # assigns attributes, processes the file, and runs validations. It also queues up
    # the previous file for deletion, to be flushed away on #save of its host.
    def assign uploaded_file
      queue_existing_for_delete
      @errors            = []
      @validation_errors = nil 

      return nil unless valid_file?(uploaded_file)

      @file                               = uploaded_file.to_tempfile
      @instance[:"#{@name}_file_name"]    = uploaded_file.original_filename
      @instance[:"#{@name}_content_type"] = uploaded_file.content_type
      @instance[:"#{@name}_file_size"]    = uploaded_file.size

      @dirty = true

      post_process
    ensure
      validate
    end

    # Returns the public URL of the attachment, with a given style. Note that this
    # does not necessarily need to point to a file that your web server can access
    # and can point to an action in your app, if you need fine grained security.
    # This is not recommended if you don't need the security, however, for
    # performance reasons.
    def url style = nil
      @file ? interpolate(@url, style) : interpolate(@default_url, style)
    end

    # Alias to +url+
    def to_s style = nil
      url(style)
    end

    # Returns true if there are any errors on this attachment.
    def valid?
      errors.length == 0
    end

    # Returns an array containing the errors on this attachment.
    def errors
      @errors.compact.uniq
    end

    # Returns true if there are changes that need to be saved.
    def dirty?
      @dirty
    end

    # Saves the file, if there are no errors. If there are, it flushes them to
    # the instance's errors and returns false, cancelling the save.
    def save
      if valid?
        flush_deletes
        flush_writes
        true
      else
        flush_errors
        false
      end
    end

    # Returns an +IO+ representing the data of the file assigned to the given
    # style. Useful for streaming with +send_file+.
    def to_io style = nil
      begin
        @processed_files[style] || File.new(path(style))
      rescue Errno::ENOENT
        nil
      end
    end

    # Returns the name of the file as originally assigned, and as lives in the
    # <attachment>_file_name attribute of the model.
    def original_filename
      instance[:"#{name}_file_name"]
    end

    # A hash of procs that are run during the interpolation of a path or url.
    # A variable of the format :name will be replaced with the return value of
    # the proc named ":name". Each lambda takes the attachment and the current
    # style as arguments. This hash can be added to with your own proc if
    # necessary.
    def self.interpolations
      @interpolations ||= {
        :rails_root   => lambda{|attachment,style| RAILS_ROOT },
        :class        => lambda{|attachment,style| attachment.instance.class.to_s.pluralize },
        :basename     => lambda do |attachment,style|
                           attachment.original_filename.gsub(/\.(.*?)$/, "")
                         end,
        :extension    => lambda do |attachment,style| 
                           ((style = attachment.styles[style]) && style.last) ||
                           File.extname(attachment.original_filename).gsub(/^\.+/, "")
                         end,
        :id           => lambda{|attachment,style| attachment.instance.id },
        :partition_id => lambda do |attachment, style|
                           ("%09d" % attachment.instance.id).scan(/\d{3}/).join("/")
                         end,
        :attachment   => lambda{|attachment,style| attachment.name.to_s.pluralize },
        :style        => lambda{|attachment,style| style || attachment.default_style },
      }
    end

    private

    def valid_file? file #:nodoc:
      file.respond_to?(:original_filename) && file.respond_to?(:content_type)
    end

    def validate #:nodoc:
      unless @validation_errors
        @validation_errors = @validations.collect do |v|
          v.call(self, instance)
        end.flatten.compact.uniq
        @errors += @validation_errors
      end
    end

    def normalize_style_definition
      @styles.each do |name, args|
        dimensions, format = [args, nil].flatten[0..1]
        format             = nil if format == ""
        @styles[name]      = [dimensions, format]
      end
    end

    def post_process #:nodoc:
      return nil if @file.nil?
      @styles.each do |name, args|
        begin
          dimensions, format = args
          @processed_files[name] = Thumbnail.make(self.file, 
                                                  dimensions, 
                                                  format, 
                                                  @whiny_thumbnails)
        rescue Errno::ENOENT  => e
          @errors << "could not be processed because the file does not exist."
        rescue PaperclipError => e
          @errors << e.message
        end
      end
      @processed_files[:original] = @file
    end

    def interpolate pattern, style = nil #:nodoc:
      style ||= @default_style
      pattern = pattern.dup
      self.class.interpolations.each do |tag, l|
        pattern.gsub!(/:#{tag}/) do |match|
          l.call( self, style )
        end
      end
      pattern.gsub(%r{/+}, "/")
    end

    def path style = nil #:nodoc:
      interpolate(@path, style)
    end

    def queue_existing_for_delete #:nodoc:
      @queued_for_delete += @processed_files.values
      @file               = nil
      @processed_files    = {}
      @instance[:"#{@name}_file_name"]    = nil
      @instance[:"#{@name}_content_type"] = nil
      @instance[:"#{@name}_file_size"]    = nil
    end

    def flush_errors #:nodoc:
      @errors.each do |error|
        instance.errors.add(name, error)
      end
    end

    def flush_writes #:nodoc:
      @processed_files.each do |style, file|
        FileUtils.mkdir_p( File.dirname(path(style)) )
        @processed_files[style] = file.stream_to(path(style)) unless file.path == path(style)
      end
      @file = @processed_files[nil]
    end

    def flush_deletes #:nodoc:
      @queued_for_delete.compact.each do |file|
        begin
          FileUtils.rm(file.path)
        rescue Errno::ENOENT => e
          # ignore them
        end
      end
      @queued_for_delete = []
    end
  end
end

