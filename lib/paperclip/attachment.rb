# encoding: utf-8
require 'uri'
require 'paperclip/url_generator'

module Paperclip
  # The Attachment class manages the files for a given attachment. It saves
  # when the model saves, deletes when the model is destroyed, and processes
  # the file upon assignment.
  class Attachment
    include IOStream

    def self.default_options
      @default_options ||= {
        :convert_options       => {},
        :default_style         => :original,
        :default_url           => "/:attachment/:style/missing.png",
        :restricted_characters => /[&$+,\/:;=?@<>\[\]\{\}\|\\\^~%# ]/,
        :hash_data             => ":class/:attachment/:id/:style/:updated_at",
        :hash_digest           => "SHA1",
        :interpolator          => Paperclip::Interpolations,
        :only_process          => [],
        :path                  => ":rails_root/public:url",
        :preserve_files        => false,
        :processors            => [:thumbnail],
        :source_file_options   => {},
        :storage               => :filesystem,
        :styles                => {},
        :url                   => "/system/:attachment/:id/:style/:filename",
        :url_generator         => Paperclip::UrlGenerator,
        :use_default_time_zone => true,
        :use_timestamp         => true,
        :whiny                 => Paperclip.options[:whiny] || Paperclip.options[:whiny_thumbnails]
      }
    end

    attr_reader :name, :instance, :default_style, :convert_options, :queued_for_write, :whiny,
                :options, :interpolator, :source_file_options, :whiny
    attr_accessor :post_processing

    # Creates an Attachment object. +name+ is the name of the attachment,
    # +instance+ is the ActiveRecord object instance it's attached to, and
    # +options+ is the same as the hash passed to +has_attached_file+.
    #
    # Options include:
    #
    # +url+ - a relative URL of the attachment. This is interpolated using +interpolator+
    # +path+ - where on the filesystem to store the attachment. This is interpolated using +interpolator+
    # +styles+ - a hash of options for processing the attachment. See +has_attached_file+ for the details
    # +only_process+ - style args to be run through the post-processor. This defaults to the empty list
    # +default_url+ - a URL for the missing image
    # +default_style+ - the style to use when don't specify an argument to e.g. #url, #path
    # +storage+ - the storage mechanism. Defaults to :filesystem
    # +use_timestamp+ - whether to append an anti-caching timestamp to image URLs. Defaults to true
    # +whiny+, +whiny_thumbnails+ - whether to raise when thumbnailing fails
    # +use_default_time_zone+ - related to +use_timestamp+. Defaults to true
    # +hash_digest+ - a string representing a class that will be used to hash URLs for obfuscation
    # +hash_data+ - the relative URL for the hash data. This is interpolated using +interpolator+
    # +hash_secret+ - a secret passed to the +hash_digest+
    # +convert_options+ - flags passed to the +convert+ command for processing
    # +source_file_options+ - flags passed to the +convert+ command that controls how the file is read
    # +processors+ - classes that transform the attachment. Defaults to [:thumbnail]
    # +preserve_files+ - whether to keep files on the filesystem when deleting to clearing the attachment. Defaults to false
    # +interpolator+ - the object used to interpolate filenames and URLs. Defaults to Paperclip::Interpolations
    # +url_generator+ - the object used to generate URLs, using the interpolator. Defaults to Paperclip::UrlGenerator
    def initialize(name, instance, options = {})
      @name              = name
      @instance          = instance

      options = self.class.default_options.merge(options)

      @options               = options
      @post_processing       = true
      @queued_for_delete     = []
      @queued_for_write      = {}
      @errors                = {}
      @dirty                 = false
      @interpolator          = options[:interpolator]
      @url_generator         = options[:url_generator].new(self, @options)
      @source_file_options   = options[:source_file_options]
      @whiny                 = options[:whiny]

      initialize_storage
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
        uploaded_filename = uploaded_file.original_filename
        uploaded_file = uploaded_file.to_file(:original)
        close_uploaded_file = uploaded_file.respond_to?(:close)
      else
        instance_write(:uploaded_file, uploaded_file) if uploaded_file
      end

      return nil unless valid_assignment?(uploaded_file)

      uploaded_file.binmode if uploaded_file.respond_to? :binmode
      self.clear

      return nil if uploaded_file.nil?

      uploaded_filename ||= uploaded_file.original_filename
      stores_fingerprint             = @instance.respond_to?("#{name}_fingerprint".to_sym)
      @queued_for_write[:original]   = to_tempfile(uploaded_file)
      instance_write(:file_name,       cleanup_filename(uploaded_filename.strip))
      instance_write(:content_type,    uploaded_file.content_type.to_s.strip)
      instance_write(:file_size,       uploaded_file.size.to_i)
      instance_write(:fingerprint,     generate_fingerprint(uploaded_file)) if stores_fingerprint
      instance_write(:updated_at,      Time.now)

      @dirty = true

      post_process(*@options[:only_process]) if post_processing

      # Reset the file size if the original file was reprocessed.
      instance_write(:file_size,   @queued_for_write[:original].size.to_i)
      instance_write(:fingerprint, generate_fingerprint(@queued_for_write[:original])) if stores_fingerprint
    ensure
      uploaded_file.close if close_uploaded_file
    end

    # Returns the public URL of the attachment with a given style. This does
    # not necessarily need to point to a file that your Web server can access
    # and can instead point to an action in your app, for example for fine grained
    # security; this has a serious performance tradeoff.
    #
    # Options:
    #
    # +timestamp+ - Add a timestamp to the end of the URL. Default: true.
    # +escape+    - Perform URI escaping to the URL. Default: true.
    #
    # Global controls (set on has_attached_file):
    #
    # +interpolator+  - The object that fills in a URL pattern's variables.
    # +default_url+   - The image to show when the attachment has no image.
    # +url+           - The URL for a saved image.
    # +url_generator+ - The object that generates a URL. Default: Paperclip::UrlGenerator.
    #
    # As mentioned just above, the object that generates this URL can be passed
    # in, for finer control. This object must respond to two methods:
    #
    # +#new(Paperclip::Attachment, options_hash)+
    # +#for(style_name, options_hash)+
    def url(style_name = default_style, options = {})
      default_options = {:timestamp => @options[:use_timestamp], :escape => true}

      if options == true || options == false # Backwards compatibility.
        @url_generator.for(style_name, default_options.merge(:timestamp => options))
      else
        @url_generator.for(style_name, default_options.merge(options))
      end
    end

    # Returns the path of the attachment as defined by the :path option. If the
    # file is stored in the filesystem the path refers to the path of the file
    # on disk. If the file is stored in S3, the path is the "key" part of the
    # URL, and the :bucket option refers to the S3 bucket.
    def path(style_name = default_style)
      path = original_filename.nil? ? nil : interpolate(path_option, style_name)
      path.respond_to?(:unescape) ? path.unescape : path
    end

    # Alias to +url+
    def to_s style_name = default_style
      url(style_name)
    end

    def default_style
      @options[:default_style]
    end

    def styles
      styling_option = @options[:styles]
      if styling_option.respond_to?(:call) || !@normalized_styles
        @normalized_styles = ActiveSupport::OrderedHash.new
        (styling_option.respond_to?(:call) ? styling_option.call(self) : styling_option).each do |name, args|
          @normalized_styles[name] = Paperclip::Style.new(name, args.dup, self)
        end
      end
      @normalized_styles
    end

    def processors
      processing_option = @options[:processors]

      if processing_option.respond_to?(:call)
        processing_option.call(instance)
      else
        processing_option
      end
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
      flush_deletes unless @options[:keep_old_files]
      flush_writes
      @dirty = false
      true
    end

    # Clears out the attachment. Has the same effect as previously assigning
    # nil to the attachment. Does NOT save. If you wish to clear AND save,
    # use #destroy.
    def clear
      queue_existing_for_delete
      @queued_for_write  = {}
      @errors            = {}
    end

    # Destroys the attachment. Has the same effect as previously assigning
    # nil to the attachment *and saving*. This is permanent. If you wish to
    # wipe out the existing attachment but not save, use #clear.
    def destroy
      unless @options[:preserve_files]
        clear
        save
      end
    end

    # Returns the uploaded file if present.
    def uploaded_file
      instance_read(:uploaded_file)
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
      if instance_read(:fingerprint)
        instance_read(:fingerprint)
      elsif @instance.respond_to?("#{name}_fingerprint".to_sym)
        @queued_for_write[:original] && generate_fingerprint(@queued_for_write[:original])
      else
        nil
      end
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

    # The time zone to use for timestamp interpolation.  Using the default
    # time zone ensures that results are consistent across all threads.
    def time_zone
      @options[:use_default_time_zone] ? Time.zone_default : Time.zone
    end

    # Returns a unique hash suitable for obfuscating the URL of an otherwise
    # publicly viewable attachment.
    def hash_key(style_name = default_style)
      raise ArgumentError, "Unable to generate hash without :hash_secret" unless @options[:hash_secret]
      require 'openssl' unless defined?(OpenSSL)
      data = interpolate(@options[:hash_data], style_name)
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest.const_get(@options[:hash_digest]).new, @options[:hash_secret], data)
    end

    def generate_fingerprint(source)
      if source.respond_to?(:path) && source.path && !source.path.blank?
        Digest::MD5.file(source.path).to_s
      else
        data = source.read
        source.rewind if source.respond_to?(:rewind)
        Digest::MD5.hexdigest(data)
      end
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
    def reprocess!(*style_args)
      new_original = Tempfile.new("paperclip-reprocess")
      new_original.binmode
      if old_original = to_file(:original)
        new_original.write( old_original.respond_to?(:get) ? old_original.get : old_original.read )
        new_original.rewind

        @queued_for_write = { :original => new_original }
        instance_write(:updated_at, Time.now)
        post_process(*style_args)

        old_original.close if old_original.respond_to?(:close)
        old_original.unlink if old_original.respond_to?(:unlink)

        save
      else
        true
      end
    rescue Errno::EACCES => e
      warn "#{e} - skipping file"
      false
    end

    # Returns true if a file has been assigned.
    def file?
      !original_filename.blank?
    end

    alias :present? :file?

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

    def path_option
      @options[:path].respond_to?(:call) ? @options[:path].call(self) : @options[:path]
    end

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
      storage_class_name = @options[:storage].to_s.downcase.camelize
      begin
        storage_module = Paperclip::Storage.const_get(storage_class_name)
      rescue NameError
        raise StorageMethodNotFound, "Cannot load storage module '#{storage_class_name}'"
      end
      self.extend(storage_module)
    end

    def extra_options_for(style) #:nodoc:
      all_options   = @options[:convert_options][:all]
      all_options   = all_options.call(instance)   if all_options.respond_to?(:call)
      style_options = @options[:convert_options][style]
      style_options = style_options.call(instance) if style_options.respond_to?(:call)

      [ style_options, all_options ].compact.join(" ")
    end

    def extra_source_file_options_for(style) #:nodoc:
      all_options   = @options[:source_file_options][:all]
      all_options   = all_options.call(instance)   if all_options.respond_to?(:call)
      style_options = @options[:source_file_options][style]
      style_options = style_options.call(instance) if style_options.respond_to?(:call)

      [ style_options, all_options ].compact.join(" ")
    end

    def post_process(*style_args) #:nodoc:
      return if @queued_for_write[:original].nil?
      instance.run_paperclip_callbacks(:post_process) do
        instance.run_paperclip_callbacks(:"#{name}_post_process") do
          post_process_styles(*style_args)
        end
      end
    end

    def post_process_styles(*style_args) #:nodoc:
      post_process_style(:original, styles[:original]) if styles.include?(:original) && process_style?(:original, style_args)
      styles.reject{ |name, style| name == :original }.each do |name, style|
        post_process_style(name, style) if process_style?(name, style_args)
      end
    end

    def post_process_style(name, style) #:nodoc:
      begin
        raise RuntimeError.new("Style #{name} has no processors defined.") if style.processors.blank?
        @queued_for_write[name] = style.processors.inject(@queued_for_write[:original]) do |file, processor|
          Paperclip.processor(processor).make(file, style.processor_options, self)
        end
      rescue PaperclipError => e
        log("An error was received while processing: #{e.inspect}")
        (@errors[:processing] ||= []) << e.message if @options[:whiny]
      end
    end

    def process_style?(style_name, style_args) #:nodoc:
      style_args.empty? || style_args.include?(style_name)
    end

    def interpolate(pattern, style_name = default_style) #:nodoc:
      interpolator.interpolate(pattern, self, style_name)
    end

    def queue_existing_for_delete #:nodoc:
      return if @options[:preserve_files] || !file?
      @queued_for_delete += [:original, *styles.keys].uniq.map do |style|
        path(style) if exists?(style)
      end.compact
      instance_write(:file_name, nil)
      instance_write(:content_type, nil)
      instance_write(:file_size, nil)
      instance_write(:fingerprint, nil)
      instance_write(:updated_at, nil)
    end

    def flush_errors #:nodoc:
      @errors.each do |error, message|
        [message].flatten.each {|m| instance.errors.add(name, m) }
      end
    end

    # called by storage after the writes are flushed and before @queued_for_writes is cleared
    def after_flush_writes
      @queued_for_write.each do |style, file|
        file.close unless file.closed?
        file.unlink if file.respond_to?(:unlink) && file.path.present? && File.exist?(file.path)
      end
    end

    def cleanup_filename(filename)
      if @options[:restricted_characters]
        filename.gsub(@options[:restricted_characters], '_')
      end
    end
  end
end
