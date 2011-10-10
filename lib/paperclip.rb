# Paperclip allows file attachments that are stored in the filesystem. All graphical
# transformations are done using the Graphics/ImageMagick command line utilities and
# are stored in Tempfiles until the record is saved. Paperclip does not require a
# separate model for storing the attachment's information, instead adding a few simple
# columns to your table.
#
# Author:: Jon Yurek
# Copyright:: Copyright (c) 2008-2011 thoughtbot, inc.
# License:: MIT License (http://www.opensource.org/licenses/mit-license.php)
#
# Paperclip defines an attachment as any file, though it makes special considerations
# for image files. You can declare that a model has an attached file with the
# +has_attached_file+ method:
#
#   class User < ActiveRecord::Base
#     has_attached_file :avatar, :styles => { :thumb => "100x100" }
#   end
#
#   user = User.new
#   user.avatar = params[:user][:avatar]
#   user.avatar.url
#   # => "/users/avatars/4/original_me.jpg"
#   user.avatar.url(:thumb)
#   # => "/users/avatars/4/thumb_me.jpg"
#
# See the +has_attached_file+ documentation for more details.

require 'erb'
require 'digest'
require 'tempfile'
require 'paperclip/options'
require 'paperclip/version'
require 'paperclip/upfile'
require 'paperclip/iostream'
require 'paperclip/geometry'
require 'paperclip/processor'
require 'paperclip/thumbnail'
require 'paperclip/interpolations'
require 'paperclip/style'
require 'paperclip/attachment'
require 'paperclip/storage'
require 'paperclip/callback_compatibility'
require 'paperclip/missing_attachment_styles'
require 'paperclip/railtie'
require 'logger'
require 'cocaine'

# The base module that gets included in ActiveRecord::Base. See the
# documentation for Paperclip::ClassMethods for more useful information.
module Paperclip

  class << self
    # Provides configurability to Paperclip. There are a number of options available, such as:
    # * whiny: Will raise an error if Paperclip cannot process thumbnails of
    #   an uploaded image. Defaults to true.
    # * log: Logs progress to the Rails log. Uses ActiveRecord's logger, so honors
    #   log levels, etc. Defaults to true.
    # * command_path: Defines the path at which to find the command line
    #   programs if they are not visible to Rails the system's search path. Defaults to
    #   nil, which uses the first executable found in the user's search path.
    # * image_magick_path: Deprecated alias of command_path.
    def options
      @options ||= {
        :whiny             => true,
        :image_magick_path => nil,
        :command_path      => nil,
        :log               => true,
        :log_command       => true,
        :swallow_stderr    => true
      }
    end

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
      if options[:image_magick_path]
        Paperclip.log("[DEPRECATION] :image_magick_path is deprecated and will be removed. Use :command_path instead")
      end
      command_path = options[:command_path] || options[:image_magick_path]
      Cocaine::CommandLine.path = ( Cocaine::CommandLine.path ? [Cocaine::CommandLine.path, command_path ].flatten : command_path )
      local_options = local_options.merge(:logger => logger) if logging? && (options[:log_command] || local_options[:log_command])
      Cocaine::CommandLine.new(cmd, arguments, local_options).run
    end

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

    # Find all instances of the given Active Record model +klass+ with attachment +name+.
    # This method is used by the refresh rake tasks.
    def each_instance_with_attachment(klass, name)
      class_for(klass).find(:all, :order => 'id').each do |instance|
        yield(instance) if instance.send(:"#{name}?")
      end
    end

    # Log a paperclip-specific line. This will logs to STDOUT
    # by default. Set Paperclip.options[:log] to false to turn off.
    def log message
      logger.info("[paperclip] #{message}") if logging?
    end

    def logger #:nodoc:
      @logger ||= options[:logger] || Logger.new(STDOUT)
    end

    def logger=(logger)
      @logger = logger
    end

    def logging? #:nodoc:
      options[:log]
    end

    def class_for(class_name)
      # Ruby 1.9 introduces an inherit argument for Module#const_get and
      # #const_defined? and changes their default behavior.
      # https://github.com/rails/rails/blob/v3.0.9/activesupport/lib/active_support/inflector/methods.rb#L89
      if Module.method(:const_get).arity == 1
        class_name.split('::').inject(Object) do |klass, partial_class_name|
          klass.const_defined?(partial_class_name) ? klass.const_get(partial_class_name) : klass.const_missing(partial_class_name)
        end
      else
        class_name.split('::').inject(Object) do |klass, partial_class_name|
          klass.const_defined?(partial_class_name) ? klass.const_get(partial_class_name, false) : klass.const_missing(partial_class_name)
        end
      end
    rescue ArgumentError => e
      # Sadly, we need to capture ArguementError here because Rails 2.3.x
      # Active Support dependency's management will try to the constant inherited
      # from Object, and fail misably with "Object is not missing constant X" error
      # https://github.com/rails/rails/blob/v2.3.12/activesupport/lib/active_support/dependencies.rb#L124
      if e.message =~ /is not missing constant/
        raise NameError, "uninitialized constant #{class_name}"
      else
        raise e
      end
    end

    def check_for_url_clash(name,url,klass)
      @names_url ||= {}
      default_url = url || Attachment.default_options[:url]
      if @names_url[name] && @names_url[name][:url] == default_url && @names_url[name][:class] != klass
        log("Duplicate URL for #{name} with #{default_url}. This will clash with attachment defined in #{@names_url[name][:class]} class")
      end
      @names_url[name] = {:url => default_url, :class => klass}
    end

    def reset_duplicate_clash_check!
      @names_url = nil
    end
  end

  class PaperclipError < StandardError #:nodoc:
  end

  class StorageMethodNotFound < PaperclipError
  end

  class CommandNotFoundError < PaperclipError
  end

  class NotIdentifiedByImageMagickError < PaperclipError #:nodoc:
  end

  class InfiniteInterpolationError < PaperclipError #:nodoc:
  end

  module Glue
    def self.included base #:nodoc:
      base.extend ClassMethods
      base.class_attribute :attachment_definitions if base.respond_to?(:class_attribute)
      if base.respond_to?(:set_callback)
        base.send :include, Paperclip::CallbackCompatability::Rails3
      else
        base.send :include, Paperclip::CallbackCompatability::Rails21
      end
    end
  end

  module ClassMethods
    # +has_attached_file+ gives the class it is called on an attribute that maps to a file. This
    # is typically a file stored somewhere on the filesystem and has been uploaded by a user.
    # The attribute returns a Paperclip::Attachment object which handles the management of
    # that file. The intent is to make the attachment as much like a normal attribute. The
    # thumbnails will be created when the new file is assigned, but they will *not* be saved
    # until +save+ is called on the record. Likewise, if the attribute is set to +nil+ is
    # called on it, the attachment will *not* be deleted until +save+ is called. See the
    # Paperclip::Attachment documentation for more specifics. There are a number of options
    # you can set to change the behavior of a Paperclip attachment:
    # * +url+: The full URL of where the attachment is publically accessible. This can just
    #   as easily point to a directory served directly through Apache as it can to an action
    #   that can control permissions. You can specify the full domain and path, but usually
    #   just an absolute path is sufficient. The leading slash *must* be included manually for
    #   absolute paths. The default value is
    #   "/system/:attachment/:id/:style/:filename". See
    #   Paperclip::Attachment#interpolate for more information on variable interpolaton.
    #     :url => "/:class/:attachment/:id/:style_:filename"
    #     :url => "http://some.other.host/stuff/:class/:id_:extension"
    # * +default_url+: The URL that will be returned if there is no attachment assigned.
    #   This field is interpolated just as the url is. The default value is
    #   "/:attachment/:style/missing.png"
    #     has_attached_file :avatar, :default_url => "/images/default_:style_avatar.png"
    #     User.new.avatar_url(:small) # => "/images/default_small_avatar.png"
    # * +styles+: A hash of thumbnail styles and their geometries. You can find more about
    #   geometry strings at the ImageMagick website
    #   (http://www.imagemagick.org/script/command-line-options.php#resize). Paperclip
    #   also adds the "#" option (e.g. "50x50#"), which will resize the image to fit maximally
    #   inside the dimensions and then crop the rest off (weighted at the center). The
    #   default value is to generate no thumbnails.
    # * +default_style+: The thumbnail style that will be used by default URLs.
    #   Defaults to +original+.
    #     has_attached_file :avatar, :styles => { :normal => "100x100#" },
    #                       :default_style => :normal
    #     user.avatar.url # => "/avatars/23/normal_me.png"
    # * +whiny+: Will raise an error if Paperclip cannot post_process an uploaded file due
    #   to a command line error. This will override the global setting for this attachment.
    #   Defaults to true. This option used to be called :whiny_thumbanils, but this is
    #   deprecated.
    # * +convert_options+: When creating thumbnails, use this free-form options
    #   array to pass in various convert command options.  Typical options are "-strip" to
    #   remove all Exif data from the image (save space for thumbnails and avatars) or
    #   "-depth 8" to specify the bit depth of the resulting conversion.  See ImageMagick
    #   convert documentation for more options: (http://www.imagemagick.org/script/convert.php)
    #   Note that this option takes a hash of options, each of which correspond to the style
    #   of thumbnail being generated. You can also specify :all as a key, which will apply
    #   to all of the thumbnails being generated. If you specify options for the :original,
    #   it would be best if you did not specify destructive options, as the intent of keeping
    #   the original around is to regenerate all the thumbnails when requirements change.
    #     has_attached_file :avatar, :styles => { :large => "300x300", :negative => "100x100" }
    #                                :convert_options => {
    #                                  :all => "-strip",
    #                                  :negative => "-negate"
    #                                }
    #   NOTE: While not deprecated yet, it is not recommended to specify options this way.
    #   It is recommended that :convert_options option be included in the hash passed to each
    #   :styles for compatibility with future versions.
    #   NOTE: Strings supplied to :convert_options are split on space in order to undergo
    #   shell quoting for safety. If your options require a space, please pre-split them
    #   and pass an array to :convert_options instead.
    # * +storage+: Chooses the storage backend where the files will be stored. The current
    #   choices are :filesystem and :s3. The default is :filesystem. Make sure you read the
    #   documentation for Paperclip::Storage::Filesystem and Paperclip::Storage::S3
    #   for backend-specific options.
    #
    # It's also possible for you to dynamicly define your interpolation string for :url,
    # :default_url, and :path in your model by passing a method name as a symbol as a argument
    # for your has_attached_file definition:
    #
    #   class Person
    #     has_attached_file :avatar, :default_url => :default_url_by_gender
    #
    #     private
    #
    #     def default_url_by_gender
    #       "/assets/avatars/default_#{gender}.png"
    #     end
    #   end
    def has_attached_file name, options = {}
      include InstanceMethods

      if attachment_definitions.nil?
        if respond_to?(:class_attribute)
          self.attachment_definitions = {}
        else
          write_inheritable_attribute(:attachment_definitions, {})
        end
      end

      attachment_definitions[name] = {:validations => []}.merge(options)
      Paperclip.classes_with_attachments << self.name
      Paperclip.check_for_url_clash(name,attachment_definitions[name][:url],self.name)

      after_save :save_attached_files
      before_destroy :prepare_for_destroy
      after_destroy :destroy_attached_files

      define_paperclip_callbacks :post_process, :"#{name}_post_process"

      define_method name do |*args|
        a = attachment_for(name)
        (args.length > 0) ? a.to_s(args.first) : a
      end

      define_method "#{name}=" do |file|
        attachment_for(name).assign(file)
      end

      define_method "#{name}?" do
        attachment_for(name).file?
      end

      validates_each(name) do |record, attr, value|
        attachment = record.attachment_for(name)
        attachment.send(:flush_errors)
      end
    end

    # Places ActiveRecord-style validations on the size of the file assigned. The
    # possible options are:
    # * +in+: a Range of bytes (i.e. +1..1.megabyte+),
    # * +less_than+: equivalent to :in => 0..options[:less_than]
    # * +greater_than+: equivalent to :in => options[:greater_than]..Infinity
    # * +message+: error message to display, use :min and :max as replacements
    # * +if+: A lambda or name of a method on the instance. Validation will only
    #   be run is this lambda or method returns true.
    # * +unless+: Same as +if+ but validates if lambda or method returns false.
    def validates_attachment_size name, options = {}
      min     = options[:greater_than] || (options[:in] && options[:in].first) || 0
      max     = options[:less_than]    || (options[:in] && options[:in].last)  || (1.0/0)
      range   = (min..max)
      message = options[:message] || "file size must be between :min and :max bytes"
      message = message.call if message.respond_to?(:call)
      message = message.gsub(/:min/, min.to_s).gsub(/:max/, max.to_s)

      validates_inclusion_of :"#{name}_file_size",
                             :in        => range,
                             :message   => message,
                             :if        => options[:if],
                             :unless    => options[:unless],
                             :allow_nil => true
    end

    # Adds errors if thumbnail creation fails. The same as specifying :whiny_thumbnails => true.
    def validates_attachment_thumbnails name, options = {}
      warn('[DEPRECATION] validates_attachment_thumbnail is deprecated. ' +
           'This validation is on by default and will be removed from future versions. ' +
           'If you wish to turn it off, supply :whiny => false in your definition.')
      attachment_definitions[name][:whiny_thumbnails] = true
    end

    # Places ActiveRecord-style validations on the presence of a file.
    # Options:
    # * +if+: A lambda or name of a method on the instance. Validation will only
    #   be run is this lambda or method returns true.
    # * +unless+: Same as +if+ but validates if lambda or method returns false.
    def validates_attachment_presence name, options = {}
      message = options[:message] || :empty
      validates_presence_of :"#{name}_file_name",
                            :message   => message,
                            :if        => options[:if],
                            :unless    => options[:unless]
    end

    # Places ActiveRecord-style validations on the content type of the file
    # assigned. The possible options are:
    # * +content_type+: Allowed content types.  Can be a single content type
    #   or an array.  Each type can be a String or a Regexp. It should be
    #   noted that Internet Explorer upload files with content_types that you
    #   may not expect. For example, JPEG images are given image/pjpeg and
    #   PNGs are image/x-png, so keep that in mind when determining how you
    #   match.  Allows all by default.
    # * +message+: The message to display when the uploaded file has an invalid
    #   content type.
    # * +if+: A lambda or name of a method on the instance. Validation will only
    #   be run is this lambda or method returns true.
    # * +unless+: Same as +if+ but validates if lambda or method returns false.
    # NOTE: If you do not specify an [attachment]_content_type field on your
    # model, content_type validation will work _ONLY upon assignment_ and
    # re-validation after the instance has been reloaded will always succeed.
    # You'll still need to have a virtual attribute (created by +attr_accessor+)
    # name +[attachment]_content_type+ to be able to use this validator.
    def validates_attachment_content_type name, options = {}
      validation_options = options.dup
      allowed_types = [validation_options[:content_type]].flatten
      validates_each(:"#{name}_content_type", validation_options) do |record, attr, value|
        if !allowed_types.any?{|t| t === value } && !(value.nil? || value.blank?)
          if record.errors.method(:add).arity == -2
            message = options[:message] || "is not one of #{allowed_types.join(", ")}"
            message = message.call if message.respond_to?(:call)
            record.errors.add(:"#{name}_content_type", message)
          else
            record.errors.add(:"#{name}_content_type", :inclusion, :default => options[:message], :value => value)
          end
        end
      end
    end

    # Returns the attachment definitions defined by each call to
    # has_attached_file.
    def attachment_definitions
      if respond_to?(:class_attribute)
        self.attachment_definitions
      else
        read_inheritable_attribute(:attachment_definitions)
      end
    end
  end

  module InstanceMethods #:nodoc:
    def attachment_for name
      @_paperclip_attachments ||= {}
      @_paperclip_attachments[name] ||= Attachment.new(name, self, self.class.attachment_definitions[name])
    end

    def each_attachment
      self.class.attachment_definitions.each do |name, definition|
        yield(name, attachment_for(name))
      end
    end

    def save_attached_files
      Paperclip.log("Saving attachments.")
      each_attachment do |name, attachment|
        attachment.send(:save)
      end
    end

    def destroy_attached_files
      Paperclip.log("Deleting attachments.")
      each_attachment do |name, attachment|
        attachment.send(:flush_deletes)
      end
    end

    def prepare_for_destroy
      Paperclip.log("Scheduling attachments for deletion.")
      each_attachment do |name, attachment|
        attachment.send(:queue_existing_for_delete)
      end
    end

  end

end
