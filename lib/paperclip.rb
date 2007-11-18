# Paperclip allows file attachments that are stored in the filesystem. All graphical
# transformations are done using the Graphics/ImageMagick command line utilities and
# are stored in-memory until the record is saved. Paperclip does not require a
# separate model for storing the attachment's information, instead adding a few simple
# columns to your table.
#
# Author:: Jon Yurek
# Copyright:: Copyright (c) 2007 thoughtbot, inc.
# License:: Distrbutes under the same terms as Ruby
#
# Paperclip defines an attachment as any file, though it makes special considerations
# for image files. You can declare that a model has an attached file with the
# +has_attached_file+ method:
#
#   class User < ActiveRecord::Base
#     has_attached_file :avatar, :thumbnails => { :thumb => "100x100" }
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

require 'paperclip/attachment_definition'
require 'paperclip/attachment'
require 'paperclip/thumbnail'
require 'paperclip/upfile'
require 'paperclip/storage/filesystem'
require 'paperclip/storage/s3'

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
  end

  module ClassMethods
    # +has_attached_file+ gives the class it is called on an attribute that maps to a file. This
    # is typically a file stored somewhere on the filesystem and has been uploaded by a user. The
    # attribute returns a Paperclip::Attachment object which handles the management of that file.
    # The intent is to make the attachment as much like a normal attribute. The thumbnails will be
    # created when the new file is assigned, but they will *not* be saved until +save+ is called on
    # the record. Likewise, if the attribute is set to +nil+ or +Paperclip::Attachment#destroy+
    # is called on it, the attachment will *not* be deleted until +save+ is called. See the
    # Paperclip::Attachment documentation for more specifics.
    # There are a number of options you can set to change the behavior of a Paperclip attachment:
    # * +url+: The full URL of where the attachment is publically accessible. This can just as easily
    #   point to a directory served directly through Apache as it can to an action that can control
    #   permissions. You can specify the full domain and path, but usually just an absolute path is
    #   sufficient. The default value is "/:class/:attachment/:id/:style_:filename". See
    #   Paperclip::Attachment#interpolate for more information on variable interpolaton.
    #     :url => "/:attachment/:id/:style_:name"
    #     :url => "http://some.other.host/stuff/:class/:id_:extension"
    # * +missing_url+: The URL that will be returned if there is no attachment assigned. This field
    #   is interpolated just as the url is. The default value is "/:class/:attachment/missing_:style.png"
    #     has_attached_file :avatar, :missing_url => "/images/default_:style_avatar.png"
    #     User.new.avatar_url(:small) # => "/images/default_small_avatar.png"
    # * +attachment_type+: If this is set to :image (which it is, by default), Paperclip will attempt to make
    #   thumbnails if they are specified.
    # * +thumbnails+: A hash of thumbnail styles and their geometries. You can find more about geometry strings
    #   at the ImageMagick website (http://www.imagemagick.org/script/command-line-options.php#resize). Paperclip
    #   also adds the "#" option (e.g. "50x50#"), which will resize the image to fit maximally inside
    #   the dimensions and then crop the rest off (weighted at the center). The default value is
    #   to generate no thumbnails.
    # * +delete_on_destroy+: When records are deleted, the attachment that goes with it is also deleted. Set
    #   this to +false+ to prevent the file from being deleted. Defaults to +true+.
    # * +default_style+: The thumbnail style that will be used by default URLs. Defaults to +original+.
    #     has_attached_file :avatar, :thumbnails => { :normal => "100x100#" },
    #                       :default_style => :normal
    #     user.avatar.url # => "/avatars/23/normal_me.png"
    # * +path+: The location of the repository of attachments on disk. This can be coordinated
    #   with the value of the +url+ option to allow files to be saved into a place where Apache
    #   can serve them without hitting your app. Defaults to ":rails_root/public/:class/:attachment/:id/:style_:filename". 
    #   By default this places the files in the app's public directory which can be served directly.
    #   If you are using capistrano for deployment, a good idea would be to make a symlink to the
    #   capistrano-created system directory from inside your app's public directory.
    #   See Paperclip::Attachment#interpolate for more information on variable interpolaton.
    #     :path_prefix => ":rails_root/public"
    #     :path_prefix => "/var/app/repository"
    def has_attached_file *attachment_names
      options = attachment_names.last.is_a?(Hash) ? attachment_names.pop : {}

      include InstanceMethods
      after_save :save_attached_files
      before_destroy :destroy_attached_files

      #class_inheritable_hash :attachment_definitions
      @attachment_definitions ||= {}
      @attachment_names       ||= []
      @attachment_names        += attachment_names

      attachment_names.each do |aname|
        whine_about_columns_for aname
        @attachment_definitions[aname] = AttachmentDefinition.new(aname, options)

        define_method aname do
          attachment_for(aname)
        end

        define_method "#{aname}=" do |uploaded_file|
          attachment_for(aname).assign uploaded_file
        end
      end
    end

    # Returns an array of all the attachments defined on this class.
    def attached_files
      @attachment_names
    end

    # Returns a AttachmentDefinition for the given attachment
    def attachment_definition_for attachment
      @attachment_definitions[attachment]
    end

    # Adds errors if the attachments you specify are either missing or had errors on them.
    # Essentially, acts like validates_presence_of for attachments.
    def validates_attached_file *attachment_names
      validates_each *attachment_names do |record, name, attachment|
        attachment.errors.each do |error|
          record.errors.add(name, error)
        end
      end
    end

    # Throws errors if the model does not contain the necessary columns.
    def whine_about_columns_for attachment #:nodoc:
      unless column_names.include?("#{attachment}_file_name") && column_names.include?("#{attachment}_content_type")
        error = "Class #{name} does not have the necessary columns to have an attachment named #{attachment}. " +
                "(#{attachment}_file_name and #{attachment}_content_type)"
        raise PaperclipError, error
      end
    end
  end

  module InstanceMethods #:nodoc:
    def attachment_for name
      @attachments ||= {}
      @attachments[name] ||= Attachment.new(self, name, self.class.attachment_definition_for(name))
    end
    
    def each_attachment
      self.class.attached_files.each do |name|
        yield(name, attachment_for(name))
      end
    end

    def save_attached_files
      each_attachment do |name, attachment|
        attachment.save
      end
    end

    def destroy_attached_files
      each_attachment do |name, attachment|
        attachment.destroy!
      end
    end
  end
end
