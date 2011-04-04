# Paperclip allows file attachments that are stored in the filesystem. All graphical
# transformations are done using the Graphics/ImageMagick command line utilities and
# are stored in Tempfiles until the record is saved. Paperclip does not require a
# separate model for storing the attachment's information, instead adding a few simple
# columns to your table.
#
# Author:: Jon Yurek
# Copyright:: Copyright (c) 2008-2009 thoughtbot, inc.
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
require 'paperclip/callback_compatability'
require 'paperclip/command_line'
require 'paperclip/railtie'
if defined?(Rails.root) && Rails.root
  Dir.glob(File.join(File.expand_path(Rails.root), "lib", "paperclip_processors", "*.rb")).each do |processor|
    require processor
  end
end

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

    # The run method takes a command to execute and an array of parameters
    # that get passed to it. The command is prefixed with the :command_path
    # option from Paperclip.options. If you have many commands to run and
    # they are in different paths, the suggested course of action is to
    # symlink them so they are all in the same directory.
    #
    # If the command returns with a result code that is not one of the
    # expected_outcodes, a PaperclipCommandLineError will be raised. Generally
    # a code of 0 is expected, but a list of codes may be passed if necessary.
    # These codes should be passed as a hash as the last argument, like so:
    #
    #   Paperclip.run("echo", "something", :expected_outcodes => [0,1,2,3])
    #
    # This method can log the command being run when
    # Paperclip.options[:log_command] is set to true (defaults to false). This
    # will only log if logging in general is set to true as well.
    def run cmd, *params
      if options[:image_magick_path]
        Paperclip.log("[DEPRECATION] :image_magick_path is deprecated and will be removed. Use :command_path instead")
      end
      CommandLine.path = options[:command_path] || options[:image_magick_path]
      CommandLine.new(cmd, *params).run
    end

    def processor name #:nodoc:
      name = name.to_s.camelize
      processor = Paperclip.const_get(name)
      unless processor.ancestors.include?(Paperclip::Processor)
        raise PaperclipError.new("Processor #{name} was not found")
      end
      processor
    end

    def each_instance_with_attachment(klass, name)
      Object.const_get(klass).all.each do |instance|
        yield(instance) if instance.send(:"#{name}?")
      end
    end

    # Log a paperclip-specific line. Uses ActiveRecord::Base.logger
    # by default. Set Paperclip.options[:log] to false to turn off.
    def log message
      logger.info("[paperclip] #{message}") if logging?
    end

    def logger #:nodoc:
      ActiveRecord::Base.logger
    end

    def logging? #:nodoc:
      options[:log]
    end
  end

  class PaperclipError < StandardError #:nodoc:
  end

  class PaperclipCommandLineError < PaperclipError #:nodoc:
    attr_accessor :output
    def initialize(msg = nil, output = nil)
      super(msg)
      @output = output
    end
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
      if base.respond_to?("set_callback")
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
    #   :styles for compatability with future versions.
    #   NOTE: Strings supplied to :convert_options are split on space in order to undergo
    #   shell quoting for safety. If your options require a space, please pre-split them
    #   and pass an array to :convert_options instead.
    # * +storage+: Chooses the storage backend where the files will be stored. The current
    #   choices are :filesystem and :s3. The default is :filesystem. Make sure you read the
    #   documentation for Paperclip::Storage::Filesystem and Paperclip::Storage::S3
    #   for backend-specific options.
    def has_attached_file name, options = {}
      include InstanceMethods

      write_inheritable_attribute(:attachment_definitions, {}) if attachment_definitions.nil?
      attachment_definitions[name] = {:validations => []}.merge(options)

      after_save :save_attached_files
      before_destroy :destroy_attached_files

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
      message = options[:message] || "file size must be between :min and :max bytes."
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
      message = options[:message] || "must be set."
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
      read_inheritable_attribute(:attachment_definitions)
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
        attachment.send(:queue_existing_for_delete)
        attachment.send(:flush_deletes)
      end
    end
  end

end
