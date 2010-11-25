# encoding: utf-8
module Paperclip
  # The Attachment class manages the files for a given attachment. It saves
  # when the model saves, deletes when the model is destroyed, and processes
  # the file upon assignment.
  class Attachment
    include IOStream

    def self.default_options
      @default_options ||= {
        :url               => "/system/:attachment/:id/:style/:filename",
        :path              => ":rails_root/public:url",
        :styles            => {},
        :processors        => [:thumbnail],
        :convert_options   => {},
        :default_url       => "/:attachment/:style/missing.png",
        :default_style     => :original,
        :storage           => :filesystem,
        :use_timestamp     => true,
        :whiny             => Paperclip.options[:whiny] || Paperclip.options[:whiny_thumbnails]
      }
    end

    attr_reader :name, :instance, :default_style, :convert_options, :queued_for_write, :whiny, :options

    # Creates an Attachment object. +name+ is the name of the attachment,
    # +instance+ is the ActiveRecord object instance it's attached to, and
    # +options+ is the same as the hash passed to +has_attached_file+.
    def initialize name, instance, options = {}
      @name              = name
      @instance          = instance

      options = self.class.default_options.merge(options)

      @url               = options[:url]
      @url               = @url.call(self) if @url.is_a?(Proc)
      @path              = options[:path]
      @path              = @path.call(self) if @path.is_a?(Proc)
      @styles            = options[:styles]
      @normalized_styles = nil
      @default_url       = options[:default_url]
      @default_style     = options[:default_style]
      @storage           = options[:storage]
      @use_timestamp     = options[:use_timestamp]
      @whiny             = options[:whiny_thumbnails] || options[:whiny]
      @convert_options   = options[:convert_options]
      @processors        = options[:processors]
      @options           = options
      @queued_for_delete = []
      @queued_for_write  = {}
      @errors            = {}
      @dirty             = false

      initialize_storage
    end

    def styles
      unless @normalized_styles
        @normalized_styles = {}
        (@styles.respond_to?(:call) ? @styles.call(self) : @styles).each do |name, args|
          @normalized_styles[name] = Paperclip::Style.new(name, args.dup, self)
        end
      end
      @normalized_styles
    end

    def processors
      @processors.respond_to?(:call) ? @processors.call(instance) : @processors
    end

    # What gets called when you call instance.attachment = File. It clears
    # errors, assigns attributes, and processes the file. It
    # also queues up the previous file for deletion, to be flushed away on
    # #save of its host.  In addition to form uploads, you can also assign
    # another Paperclip attachment:
    #   new_user.avatar = old_user.avatar
    def assign uploaded_file
      ensure_required_accessors!

      if uploaded_file.is_a?(Paperclip::Attachment)
        uploaded_file = uploaded_file.to_file(:original)
        close_uploaded_file = uploaded_file.respond_to?(:close)
      end

      return nil unless valid_assignment?(uploaded_file)

      uploaded_file.binmode if uploaded_file.respond_to? :binmode
      self.clear

      return nil if uploaded_file.nil?

      @queued_for_write[:original]   = to_tempfile(uploaded_file)
      instance_write(:file_name,       uploaded_file.original_filename.strip)
      instance_write(:content_type,    uploaded_file.content_type.to_s.strip)
      instance_write(:file_size,       uploaded_file.size.to_i)
      instance_write(:fingerprint,     generate_fingerprint(uploaded_file))
      instance_write(:updated_at,      Time.now)

      @dirty = true

      post_process

      # Reset the file size if the original file was reprocessed.
      instance_write(:file_size,   @queued_for_write[:original].size.to_i)
      instance_write(:fingerprint, generate_fingerprint(@queued_for_write[:original]))
    ensure
      uploaded_file.close if close_uploaded_file
    end

    # Returns the public URL of the attachment, with a given style. Note that
    # this does not necessarily need to point to a file that your web server
    # can access and can point to an action in your app, if you need fine
    # grained security.  This is not recommended if you don't need the
    # security, however, for performance reasons. Set use_timestamp to false
    # if you want to stop the attachment update time appended to the url
    def url(style_name = default_style, use_timestamp = @use_timestamp)
      url = original_filename.nil? ? interpolate(@default_url, style_name) : interpolate(@url, style_name)
      use_timestamp && updated_at ? [url, updated_at].compact.join(url.include?("?") ? "&" : "?") : url
    end

    # Returns the path of the attachment as defined by the :path option. If the
    # file is stored in the filesystem the path refers to the path of the file
    # on disk. If the file is stored in S3, the path is the "key" part of the
    # URL, and the :bucket option refers to the S3 bucket.
    def path style_name = default_style
      original_filename.nil? ? nil : interpolate(@path, style_name)
    end

    # Alias to +url+
    def to_s style_name = nil
      url(style_name)
    end

    # Returns an array containing the errors on this attachment.
    def errors
      @errors
    end

    # Returns true if there are changes that need to be saved.
    def dirty?
      @dirty
    end

    # Saves the file, if there are no errors. If there are, it flushes them to
    # the instance's errors and returns false, cancelling the save.
    def save
      flush_deletes
      flush_writes
      @dirty = false
      true
    end

    # Clears out the attachment. Has the same effect as previously assigning
    # nil to the attachment. Does NOT save. If you wish to clear AND save,
    # use #destroy.
    def clear
      queue_existing_for_delete
      @errors            = {}
    end

    # Destroys the attachment. Has the same effect as previously assigning
    # nil to the attachment *and saving*. This is permanent. If you wish to
    # wipe out the existing attachment but not save, use #clear.
    def destroy
      clear
      save
    end

    # Returns the name of the file as originally assigned, and lives in the
    # <attachment>_file_name attribute of the model.
    def original_filename
      instance_read(:file_name)
    end

    # Returns the size of the file as originally assigned, and lives in the
    # <attachment>_file_size attribute of the model.
    def size
      instance_read(:file_size) || (@queued_for_write[:original] && @queued_for_write[:original].size)
    end

    # Returns the hash of the file as originally assigned, and lives in the
    # <attachment>_fingerprint attribute of the model.
    def fingerprint
      instance_read(:fingerprint) || (@queued_for_write[:original] && generate_fingerprint(@queued_for_write[:original]))
    end

    # Returns the content_type of the file as originally assigned, and lives
    # in the <attachment>_content_type attribute of the model.
    def content_type
      instance_read(:content_type)
    end

    # Returns the last modified time of the file as originally assigned, and
    # lives in the <attachment>_updated_at attribute of the model.
    def updated_at
      time = instance_read(:updated_at)
      time && time.to_f.to_i
    end

    def generate_fingerprint(source)
      data = source.read
      source.rewind if source.respond_to?(:rewind)
      Digest::MD5.hexdigest(data)
    end

    # Paths and URLs can have a number of variables interpolated into them
    # to vary the storage location based on name, id, style, class, etc.
    # This method is a deprecated access into supplying and retrieving these
    # interpolations. Future access should use either Paperclip.interpolates
    # or extend the Paperclip::Interpolations module directly.
    def self.interpolations
      warn('[DEPRECATION] Paperclip::Attachment.interpolations is deprecated ' +
           'and will be removed from future versions. ' +
           'Use Paperclip.interpolates instead')
      Paperclip::Interpolations
    end

    # This method really shouldn't be called that often. It's expected use is
    # in the paperclip:refresh rake task and that's it. It will regenerate all
    # thumbnails forcefully, by reobtaining the original file and going through
    # the post-process again.
    def reprocess!
      new_original = Tempfile.new("paperclip-reprocess")
      new_original.binmode
      if old_original = to_file(:original)
        new_original.write( old_original.respond_to?(:get) ? old_original.get : old_original.read )
        new_original.rewind

        @queued_for_write = { :original => new_original }
        post_process

        old_original.close if old_original.respond_to?(:close)

        save
      else
        true
      end
    end

    # Returns true if a file has been assigned.
    def file?
      !original_filename.blank?
    end

    # Writes the attachment-specific attribute on the instance. For example,
    # instance_write(:file_name, "me.jpg") will write "me.jpg" to the instance's
    # "avatar_file_name" field (assuming the attachment is called avatar).
    def instance_write(attr, value)
      setter = :"#{name}_#{attr}="
      responds = instance.respond_to?(setter)
      self.instance_variable_set("@_#{setter.to_s.chop}", value)
      instance.send(setter, value) if responds || attr.to_s == "file_name"
    end

    # Reads the attachment-specific attribute on the instance. See instance_write
    # for more details.
    def instance_read(attr)
      getter = :"#{name}_#{attr}"
      responds = instance.respond_to?(getter)
      cached = self.instance_variable_get("@_#{getter}")
      return cached if cached
      instance.send(getter) if responds || attr.to_s == "file_name"
    end

    private

    def ensure_required_accessors! #:nodoc:
      %w(file_name).each do |field|
        unless @instance.respond_to?("#{name}_#{field}") && @instance.respond_to?("#{name}_#{field}=")
          raise PaperclipError.new("#{@instance.class} model missing required attr_accessor for '#{name}_#{field}'")
        end
      end
    end

    def log message #:nodoc:
      Paperclip.log(message)
    end

    def valid_assignment? file #:nodoc:
      file.nil? || (file.respond_to?(:original_filename) && file.respond_to?(:content_type))
    end

    def initialize_storage #:nodoc:
      storage_class_name = @storage.to_s.capitalize
      begin
        @storage_module = Paperclip::Storage.const_get(storage_class_name)
      rescue NameError
        raise StorageMethodNotFound, "Cannot load storage module '#{storage_class_name}'"
      end
      self.extend(@storage_module)
    end

    def extra_options_for(style) #:nodoc:
      all_options   = convert_options[:all]
      all_options   = all_options.call(instance)   if all_options.respond_to?(:call)
      style_options = convert_options[style]
      style_options = style_options.call(instance) if style_options.respond_to?(:call)

      [ style_options, all_options ].compact.join(" ")
    end

    def post_process #:nodoc:
      return if @queued_for_write[:original].nil?
      instance.run_paperclip_callbacks(:post_process) do
        instance.run_paperclip_callbacks(:"#{name}_post_process") do
          post_process_styles
        end
      end
    end

    def post_process_styles #:nodoc:
      styles.each do |name, style|
        begin
          raise RuntimeError.new("Style #{name} has no processors defined.") if style.processors.blank?
          @queued_for_write[name] = style.processors.inject(@queued_for_write[:original]) do |file, processor|
            Paperclip.processor(processor).make(file, style.processor_options, self)
          end
        rescue PaperclipError => e
          log("An error was received while processing: #{e.inspect}")
          (@errors[:processing] ||= []) << e.message if @whiny
        end
      end
    end

    def interpolate pattern, style_name = default_style #:nodoc:
      Paperclip::Interpolations.interpolate(pattern, self, style_name)
    end

    def queue_existing_for_delete #:nodoc:
      return unless file?
      @queued_for_delete += [:original, *styles.keys].uniq.map do |style|
        path(style) if exists?(style)
      end.compact
      instance_write(:file_name, nil)
      instance_write(:content_type, nil)
      instance_write(:file_size, nil)
      instance_write(:updated_at, nil)
    end

    def flush_errors #:nodoc:
      @errors.each do |error, message|
        [message].flatten.each {|m| instance.errors.add(name, m) }
      end
    end

  end
end
