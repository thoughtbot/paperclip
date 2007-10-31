# Paperclip allows file attachments that are stored in the filesystem. All graphical
# transformations are done using the Graphics/ImageMagick command line utilities and
# are stored in-memory until the record is saved. Paperclip does not require a
# separate model for storing the attachment's information, and it only requires two
# columns per attachment.
#
# Author:: Jon Yurek
# Copyright:: Copyright (c) 2007 thoughtbot, inc.
# License:: Distrbutes under the same terms as Ruby
#
# See the +has_attached_file+ documentation for more details.

require 'paperclip/upfile'
require 'paperclip/attachment'
require 'paperclip/attachment_definition'
require 'paperclip/storage/filesystem'

module Thoughtbot #:nodoc:
  # Paperclip defines an attachment as any file, though it makes special considerations
  # for image files. You can declare that a model has an attached file with the
  # +has_attached_file+ method:
  #
  #   class User < ActiveRecord::Base
  #     has_attached_file :avatar, :thumbnails => { :thumb => "100x100" }
  #   end
  #
  # See the +has_attached_file+ documentation for more details.
  module Paperclip

    class << self
      # Provides configurability to Paperclip. There are a number of options available, such as:
      # * whiny_deletes: Will raise an error if Paperclip is unable to delete an attachment. Defaults to false.
      # * whiny_thumbnails: Will raise an error if Paperclip cannot process thumbnails of an uploaded image. Defaults to true.
      # * image_magick_path: Defines the path at which to find the +convert+ and +identify+ programs if they are
      #   not visible to Rails the system's search path. Defaults to nil, which uses the first executable found
      #   in the search path.
      def options
        @options ||= {
          :whiny_deletes     => false,
          :whiny_thumbnails  => true,
          :image_magick_path => nil
        }
      end

      def path_for_command command #:nodoc:
        path = [options[:image_magick_path], command].compact
        File.join(*path)
      end
    end
    
    class PaperclipError < StandardError #:nodoc:
      attr_accessor :attachment
      def initialize attachment
        @attachment = attachment
      end
    end

    module ClassMethods
      # == Methods
      # +has_attached_file+ attaches a file (or files) with a given name to a model. It creates seven instance
      # methods using the attachment name (where "attachment" in the following is the name
      # passed in to +has_attached_file+):
      # * attachment:  Returns the name of the file that was attached, with no path information.
      # * attachment?: Alias for _attachment_ for clarity in determining if the attachment exists.
      # * attachment=(file): Sets the attachment to the file and creates the thumbnails (if necessary).
      #   +file+ can be anything normally accepted as an upload (+StringIO+ or +Tempfile+) or a +File+
      #   if it has had the +Upfile+ module included.
      #   Note this does not save the attachments.
      #     user.avatar = File.new("~/pictures/me.png")
      #     user.avatar = params[:user][:avatar] # When :avatar is a file_field
      # * attachment_file_name(style): The name of the file, including path information. Pass in the
      #   name of a thumbnail to get the path to that thumbnail.
      #     user.avatar_file_name(:thumb) # => "public/users/44/thumb/me.png"
      #     user.avatar_file_name         # => "public/users/44/original/me.png"
      # * attachment_url(style): The public URL of the attachment, suitable for passing to +image_tag+
      #   or +link_to+. Pass in the name of a thumbnail to get the url to that thumbnail.
      #     user.avatar_url(:thumb) # => "http://assethost.com/users/44/thumb/me.png"
      #     user.avatar_url         # => "http://assethost.com/users/44/original/me.png"
      # * attachment_valid?: If unsaved, returns true if all thumbnails have data (that is,
      #   they were successfully made). If saved, returns true if all expected files exist and are
      #   of nonzero size.
      # * destroy_attachment(complain = false): Deletes the attachment and all thumbnails. Sets the +attachment_file_name+
      #   column and +attachment_content_type+ column to +nil+. Set +complain+ to true to override
      #   the +whiny_deletes+ option.
      #
      # == Options
      # There are a number of options you can set to change the behavior of Paperclip.
      # * +path_prefix+: The location of the repository of attachments on disk. See Interpolation below
      #   for more control over where the files are located.
      #     :path_prefix => ":rails_root/public"
      #     :path_prefix => "/var/app/repository"
      # * +url_prefix+: The root URL of where the attachment is publically accessible. See Interpolation below
      #   for more control over where the files are located.
      #     :url_prefix => "/"
      #     :url_prefix => "/user_files"
      #     :url_prefix => "http://some.other.host/stuff"
      # * +path+: Where the files are stored underneath the +path_prefix+ directory and underneath the +url_prefix+ URL.
      #   See Interpolation below for more control over where the files are located.
      #     :path => ":class/:style/:id/:name" # => "users/original/13/picture.gif"
      # * +attachment_type+: If this is set to :image (which it is, by default), Paperclip will attempt to make thumbnails.
      # * +thumbnails+: A hash of thumbnail styles and their geometries. You can find more about geometry strings
      #   at the ImageMagick website (http://www.imagemagick.org/script/command-line-options.php#resize). Paperclip
      #   also adds the "#" option, which will resize the image to fit maximally inside the dimensions and then crop
      #   the rest off (weighted at the center).
      # * +delete_on_destroy+: When records are deleted, the attachment that goes with it is also deleted. Set
      #   this to +false+ to prevent the file from being deleted.
      # * +default_style+: The thumbnail style that will be used by default for +attachment_file_name+ and +attachment_url+
      #   Defaults to +original+.
      #     has_attached_file :avatar, :thumbnails => { :normal => "100x100#" },
      #                       :default_style => :normal
      #     user.avatar_url # => "/avatars/23/normal_me.png"
      # * +missing_url+: The URL that will be returned if there is no attachment assigned. It should be an absolute
      #   URL, not relative to the +url_prefix+. This field is interpolated.
      #     has_attached_file :avatar, :missing_url => "/images/default_:style_avatar.png"
      #     User.new.avatar_url(:small) # => "/images/default_small_avatar.png"
      #
      # == Interpolation
      # The +path_prefix+, +url_prefix+, and +path+ options can have dynamic interpolation done so that the 
      # locations of the files can vary depending on a variety of factors. Each variable looks like a Ruby symbol
      # and is searched for with +gsub+, so a variety of effects can be achieved. The list of possible variables
      # follows:
      # * +rails_root+: The value of the +RAILS_ROOT+ constant for your app. Typically used when putting your
      #   attachments into the public directory. Probably not useful in the +path+ definition.
      # * +class+: The underscored, pluralized version of the class in which the attachment is defined.
      # * +attachment+: The pluralized name of the attachment as given to +has_attached_file+
      # * +style+: The name of the thumbnail style for the current thumbnail. If no style is given, "original" is used.
      # * +id+: The record's id.
      # * +name+: The file's name, as stored in the attachment_file_name column.
      #
      # When interpolating, you are not confined to making any one of these into its own directory. This is
      # perfectly valid:
      #   :path => ":attachment/:style/:id-:name" # => "avatars/thumb/44-me.png"
      #
      # == Model Requirements
      # For any given attachment _foo_, the model the attachment is in needs to have both a +foo_file_name+
      # and +foo_content_type+ column, as a type of +string+, and a +foo_file_size+ column as type +integer+.
      # The +foo_file_name+ column contains only the name
      # of the file and none of the path information. However, the +foo_file_name+ column accessor is overwritten
      # by the one (defined above) which returns the full path to whichever style thumbnail is passed in.
      # To access the name as stored in the database, you can use Attachment#original_filename.
      #
      # == Event Triggers
      # When an attachment is set by using he setter (+model.attachment=+), the thumbnails are created and held in
      # memory. They are not saved until the +after_save+ trigger fires, at which point the attachment and all
      # thumbnails are written to disk.
      #
      # Attached files are destroyed when the associated record is destroyed in a +before_destroy+ trigger. Set
      # the +delete_on_destroy+ option to +false+ to prevent this behavior. Also note that using the ActiveRecord's
      # +delete+ method instead of the +destroy+ method will prevent the +before_destroy+ trigger from firing.
      def has_attached_file *attachment_names
        options = attachment_names.last.is_a?(Hash) ? attachment_names.pop : {}
        @attachment_definitions ||= {}
        
        class << self
          attr_reader :attachment_definitions
        end
        
        include InstanceMethods
        after_save :save_attachments
        before_destroy :destroy_attachments
        
        validates_each(*attachment_names) do |record, attr, value|
          value.errors.each{|e| record.errors.add(attr, e) unless record.errors.on(attr) && record.errors.on(attr).include?(e) }
        end

        attachment_names.each do |name|
          whine_about_columns_for name
          @attachment_definitions[name] = Thoughtbot::Paperclip::AttachmentDefinition.new(name, options)
          
          define_method "#{name}=" do |uploaded_file|
            attachment_for(name).assign uploaded_file
          end
          
          define_method name do
            attachment_for(name)
          end
          
          define_method "#{name}?" do
            attachment_for(name).original_filename
          end
          
          define_method "#{name}_valid?" do
            attachment_for(name).valid?
          end
          
          define_method "#{name}_file_name" do |*args|
            attachment_for(name).file_name(args.first)
          end
          
          define_method "#{name}_url" do |*args|
            attachment_for(name).url(args.first)
          end
          
          define_method "destroy_#{name}" do |*args|
            attachment_for(name).queue_destroy(args.first)
          end
        end
      end
      
      module InstanceMethods #:nodoc:
        unless method_defined? :after_initialize
          def after_initialize
            # We need this, because Rails won't even try this method unless it is specifically defined.
          end
        end
        
        def after_initialize_with_paperclip
          @attachments = {}
          self.class.attachment_definitions.keys.each do |name|
            @attachments[name] = Thoughtbot::Paperclip::Attachment.new(name, self)
          end
        end
        alias_method_chain :after_initialize, :paperclip
        
        def save_attachments
          @attachments.each do |name, attachment|
            attachment.save
          end
        end
        
        def destroy_attachments
          @attachments.each do |name, attachment|
            attachment.destroy
          end
        end
        
        def attachment_for name
          @attachments[name]
        end
      end
      
      def attachment_names
        @attachment_definitions.keys
      end

      # Paperclip always validates whether or not file creation was successful, but does not validate
      # the presence or size of the file unless told. You can specify validations either in the
      # has_attached_file call or with a separate validates_attached_file call, with a syntax similar
      # to has_attached_file. If no options are given, the existence of the file is validated.
      #
      #   validates_attached_file :avatar, :existence => true, :size => 0..(500.kilobytes)
      def validates_attached_file *attachment_names
        options = attachment_names.pop if attachment_names.last.is_a? Hash
        options ||= { :existence => true }
        attachment_names.each do |name|
          options.each do |key, value|
            @attachment_definitions[name].validate key, value
          end
        end
      end
      
      def whine_about_columns_for name #:nodoc:
        [ "#{name}_file_name", "#{name}_content_type", "#{name}_file_size" ].each do |column|
          unless column_names.include?(column)
            raise PaperclipError, "Class #{self.name} does not have all of the necessary columns to have an attachment named #{name}. " + 
                                  "(#{name}_file_name, #{name}_content_type, and #{name}_file_size)"
          end
        end
      end
      
    end
    
    # == Storage Subsystems
    # While Paperclip focuses primarily on using the filesystem for data storage, it is possible to allow
    # other storage mediums. A module inside the Storage module can be used as the storage provider for
    # attachments when has_attached_file is given the +storage+ option. The value of the option should be
    # the name of the module, symbol-ized (e.g. :filesystem, :s3). You can look at the Filesystem and S3
    # modules for examples of how it typically works.
    #
    # If you want to implement a storage system, you are required to implement the following methods:
    # * file_name(style = nil): Takes a style (i.e. thumbnail name) and should return the canonical name
    #   for referencing that file or thumbnail. You may define this how you wish. For example, in 
    #   Filesystem, it is the location of the file under the path_prefix. In S3, it returns the path portion
    #   of the Amazon URL minus the bucket name.
    # * url(style = nil): Takes a style and should return the URL at which the attachment should be accessed.
    # * write_attachment: Write all the files and thumbnails in this attachment to the storage medium. Should
    #   return true or false depending on success.
    # * delete_attachment: Delete the files and thumbnails from the storage medium. Should return true or false
    #   depending on success.
    #
    # When writing a storage system, your code will be mixed into the Attachment that the file represents. You
    # will therefore have access to all of the methods available to Attachments. Some methods of note are:
    # * definition: Returns the AttachmentDefintion object created by has_attached_file. Useful for getting
    #   style definitions and flags that you want to set. You should open the AttachmentDefinition class to
    #   add getters for any options you want to be able to set.
    # * instance: Returns the ActiveRecord object that the Attachment is attached to. Can be used to obtain ids.
    # * original_filename: Returns the original_filename, which is the same as the attachment_file_name column
    #   in the database. Should be nil if there is no attachment.
    # * original_file_size: Returns the size of the original file, as passed to Attachment#assign.
    # * interpolate: Given a style and a pattern, this will interpolate variables like :rails_root, :name,
    #   and :id. See documentation for has_attached_file for more info on interpolation.
    # * for_attached_files: Iterates over the collection of files for this attachment, passing the style name
    #   and the data to the block. Will not call the block if the data is nil.
    # * dirty?: Returns true if a new file has been assigned with Attachment#assign, false otherwise.
    #
    # == Validations
    # Storage systems provide their own validations, since the manner of checking the status of them is usually
    # specific to the means of storage. To provide a validation, define a method starting with "validate_" in
    # your module. You are responsible for adding errors to the +errors+ array if validation fails.
    module Storage; end
  end
end
