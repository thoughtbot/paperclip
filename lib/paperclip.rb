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

  # Holds the options defined by a call to has_attached_file. If options are not defined here as methods
  # they will still be found through +method_missing+. Default values can be modified by modifying the
  # hash returned by AttachmentDefinition.defaults directly.
  class AttachmentDefinition
    def self.defaults
      @defaults ||= {
        :path               => ":rails_root/public/:class/:attachment/:id/:style_:name",
        :url                => "/:class/:attachment/:id/:style_:name",
        :missing_url        => "/:class/:attachment/:style_missing.png",
        :attachment_type    => :image,
        :thumbnails         => {},
        :delete_on_destroy  => true,
        :default_style      => :original
      }
    end

    def initialize name, options
      @name    = name
      @options = AttachmentDefinition.defaults.merge options
    end

    def name
      @name
    end

    def styles
      @styles ||= thumbnails.merge(:original => nil)
    end
    
    def thumbnails
      @thumbnails ||= @options[:thumbnails]
    end

    def validate thing, *constraints
      @options[:"validate_#{thing}"] = (constraints.length == 1 ? constraints.first : constraints)
    end

    def validations
      @validations ||= @options.inject({}) do |valids, opts|
        key, val = opts
        if (m = key.to_s.match(/^validate_(.+)/))
          valids[m[1]] = val
        end
        valids
      end
    end

    def method_missing meth, *args
      @options[meth]
    end
  end

  # == Attachment
  # Handles all the file management for the attachment, including saving, loading, presenting URLs, thumbnail
  # processing, and database storage.
  class Attachment
    attr_reader :name, :instance, :original_filename, :content_type, :original_file_size, :definition, :errors

    def initialize name, active_record, definition
      @instance   = active_record
      @definition = defintiion
      @name       = name
      @errors     = []

      clear_files
      @dirty = true
      
      self.original_filename  = @instance["#{name}_file_name"]
      self.content_type       = @instance["#{name}_content_type"]
      self.original_file_size = @instance["#{name}_file_size"]
    end

    def assign uploaded_file
      return queue_destroy if uploaded_file.nil?
      return unless is_a_file? uploaded_file

      self.original_filename  = sanitize_filename(uploaded_file.original_filename)
      self.content_type       = uploaded_file.content_type
      self.original_file_size = uploaded_file.size
      self[:original]         = uploaded_file
      @dirty                  = true

      if definition.type == :image
        make_thumbnails_from uploaded_file
      end
    end

    def [](style)
      @files[style]
    end

    def []=(style, data)
      @files[style] = data
    end

    def clear_files
      @files = {}
      definition.styles.each{|style| @files[style] = nil }
      @dirty = false
    end

    def for_attached_files
      @files.each do |style, data|
        data.rewind if data && data.respond_to?(:rewind)
        yield style, (data.respond_to?(:read) ? data.read : data)
      end
    end

    def dirty?
      @dirty
    end

    # Validations

    def valid?
      definition.validations.each do |validation, constraints|
        send("validate_#{validation}", *constraints)
      end
      errors.uniq!.empty?
    end

    # ActiveRecord Callbacks

    def save
      write_attachment  if dirty?
      delete_attachment if @delete_on_save
      @delete_on_save = false
      clear_files
    end

    def queue_destroy(complain = false)
      returning true do
        @delete_on_save        = true
        @complain_on_delete    = complain
        self.original_filename = nil
        self.content_type      = nil
        clear_files
      end
    end

    def destroy
      delete_attachment if definition.delete_on_destroy
    end

    def url style = nil
      style ||= definition.default_style
      pattern = if original_filename && instance.id
        definition.url
      else
        definition.missing_url
      end
      interpolate( style, pattern )
    end
    
    def read style = nil
      self[style] ? self[style].read : IO.read(file_name(style))  
    end

    def validate_existence *constraints
      definition.styles.keys.each do |style|
        errors << "requires a valid #{style} file." unless file_exists?(style)
      end
    end

    def validate_size *constraints
      errors << "file too large. Must be under #{constraints.last} bytes." if original_file_size > constraints.last
      errors << "file too small. Must be over #{constraints.first} bytes." if original_file_size <= constraints.first
    end

    protected

    def write_attachment
      ensure_directories
      for_attached_files do |style, data|
        File.open( file_name(style), "w" ) do |file|
          file.rewind
          file.write(data) if data
        end
      end
    end

    def delete_attachment complain = false
      for_attached_files do |style, data|
        file_path = file_name(style)
        begin
          FileUtils.rm file_path if file_path
        rescue SystemCallError => e
          raise PaperclipError, "Could not delete thumbnail." if Paperclip.options[:whiny_deletes] || complain
        end
      end
    end
    
    def file_name style = nil
      style ||= definition.default_style
      interpolate( style, definition.path )
    end

    def file_exists?(style)
      style ||= definition.default_style
      dirty? ? self[style] : File.exists?( file_name(style) )
    end

    def ensure_directories
      for_attached_files do |style, file|
        dirname = File.dirname( file_name(style) )
        FileUtils.mkdir_p dirname
      end
    end

    # Image Methods
    public

    def make_thumbnails_from data
      begin
        definition.thumbnails.each do |style, geometry|
          self[style] = make_thumbnail geometry, data
        end
      rescue PaperclipError => e
        errors << e.message
        clear_files
        self[:original] = data
      end
    end
    
    protected

    def make_thumbnail geometry, data
      return data if geometry.nil?

      operator = geometry[-1,1]
      begin
        geometry, crop_geometry = geometry_for_crop(geometry, data) if operator == '#'
        convert = Paperclip.path_for_command("convert")
        command = "#{convert} - -scale '#{geometry}' #{operator == '#' ? "-crop '#{crop_geometry}'" : ""} - 2>/dev/null"
        thumb = IO.popen(command, "w+") do |io|
          data.rewind
          io.write(data.read)
          io.close_write
          StringIO.new(io.read)
        end
      rescue Errno::EPIPE => e
        raise PaperclipError, "could not be thumbnailed. Is ImageMagick or GraphicsMagick installed and available?"
      rescue SystemCallError => e
        raise PaperclipError, "could not be thumbnailed."
      end
      if Paperclip.options[:whiny_thumbnails] && !$?.success?
        raise PaperclipError, "could not be thumbaniled because of an error with 'convert'."
      end
      thumb
    end

    def geometry_for_crop geometry, orig_io
      identify = Paperclip.path_for_command("identify")
      IO.popen("#{identify} -", "w+") do |io|
        orig_io.rewind
        io.write(orig_io.read)
        io.close_write
        if match = io.read.split[2].match(/(\d+)x(\d+)/)
          src   = match[1,2].map(&:to_f)
          srch  = src[0] > src[1]
          dst   = geometry.match(/(\d+)x(\d+)/)[1,2].map(&:to_f)
          dsth  = dst[0] > dst[1]
          ar    = src[0] / src[1]

          scale_geometry, scale = if dst[0] == dst[1]
            if srch
              [ "x#{dst[1]}", src[1] / dst[1] ]
            else
              [ "#{dst[0]}x", src[0] / dst[0] ]
            end
          elsif dsth
            [ "#{dst[0]}x", src[0] / dst[0] ]
          else
            [ "x#{dst[1]}", src[1] / dst[1] ]
          end

          crop_geometry = if dsth
            "%dx%d+%d+%d" % [ dst[0], dst[1], 0, (src[1] / scale - dst[1]) / 2 ]
          else
            "%dx%d+%d+%d" % [ dst[0], dst[1], (src[0] / scale - dst[0]) / 2, 0 ]
          end

          [ scale_geometry, crop_geometry ]
        end
      end
    end

    # Helper Methods
    
    public

    def interpolations
      @interpolations ||= {
        :rails_root => lambda{|style| RAILS_ROOT },
        :id         => lambda{|style| self.instance.id },
        :class      => lambda{|style| self.instance.class.to_s.underscore.pluralize },
        :style      => lambda{|style| style.to_s },
        :attachment => lambda{|style| self.name.to_s.pluralize },
        :filename   => lambda{|style| self.original_filename }
      }
    end

    def interpolate style, source
      returning source.dup do |s|
        interpolations.each do |key, proc|
          s.gsub!(/:#{key}/){ proc.call(instance, style) }
        end
      end
    end

    def original_filename= new_name
      instance["#{name}_file_name"] = @original_filename = new_name
    end

    def content_type= new_type
      instance["#{name}_content_type"] = @content_type = new_type
    end

    def original_file_size= new_size
      instance["#{name}_file_size"] = @original_file_size = new_size
    end

    def to_s
      url
    end
    
    protected

    def is_a_file? data
      [:size, :content_type, :original_filename, :read].map do |meth|
        data.respond_to? meth
      end.all?
    end

    def sanitize_filename filename
      File.basename(filename).gsub(/[^\w\.\_]/,'_')
    end
  end


  module ClassMethods
    def has_attached_file *attachment_names
      options = attachment_names.last.is_a?(Hash) ? attachment_names.pop : {}

      include InstanceMethods
      class_inheritable_hash :attachment_definitions

      attachment_names.each do |aname|
        whine_about_columns_for aname
        self.attachment_definitions[aname] = AttachmentDefinition.new(aname, options)

        define_method aname do
          attachment_for(aname)
        end

        define_method "#{aname}=" do |uploaded_file|
          attachment_for(aname).assign uploaded_file
        end
      end
    end

    def attached_files
      attachment_definitions.keys
    end

    # Adds errors if the attachments you specify are either missing or had errors on them.
    # Essentially, acts like validates_presence_of for attachments.
    def validates_attached_file *attachment_names
      validates_each *attachment_names do |record, name, attachment|
        attachment.errors.each do |error|
          record.add(name, error)
        end
      end
    end

    def whine_about_columns_for attachment #:nodoc:
      name = attachment[:name]
      unless column_names.include?("#{name}_file_name") && column_names.include?("#{name}_content_type")
        error = "Class #{self.name} does not have the necessary columns to have an attachment named #{name}. " +
                "(#{name}_file_name and #{name}_content_type)"
        raise PaperclipError, error
      end
    end
  end

  module InstanceMethods #:nodoc:
    def attachment_for name
      @attachments ||= {}
      @attachments[name] ||= Attachment.new(self, name)
    end
  end

  # The Upfile module is a convenience module for adding uploaded-file-type methods
  # to the +File+ class. Useful for testing.
  #   user.avatar = File.new("test/test_avatar.jpg")
  module Upfile
    # Infer the MIME-type of the file from the extension.
    def content_type
      type = self.path.match(/\.(\w+)$/)[1] || "data"
      case type
      when "jpg", "png", "gif" then "image/#{type}"
      when "txt", "csv", "xml", "html", "htm" then "text/#{type}"
      else "x-application/#{type}"
      end
    end

    # Returns the file's normal name.
    def original_filename
      self.path
    end

    # Returns the size of the file.
    def size
      File.size(self)
    end
  end
end
