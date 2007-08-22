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
    
    PAPERCLIP_OPTIONS = {
      :whiny_deletes    => false,
      :whiny_thumbnails => true
    }
    
    def self.options
      PAPERCLIP_OPTIONS
    end
    
    DEFAULT_ATTACHMENT_OPTIONS = {
      :path_prefix       => ":rails_root/public",
      :url_prefix        => "",
      :path              => ":attachment/:id/:style_:name",
      :attachment_type   => :image,
      :thumbnails        => {},
      :delete_on_destroy => true,
      :default_style     => :original,
      :missing_url       => "",
      :missing_path      => ""
    }
    
    class PaperclipError < StandardError #:nodoc:
      attr_accessor :attachment, :reason, :exception
      def initialize attachment, reason, exception = nil
        @attachment, @reason, @exception = *args
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
      # and +foo_content_type+ column, as a type of +string+. The +foo_file_name+ column contains only the name
      # of the file and none of the path information. However, the +foo_file_name+ column accessor is overwritten
      # by the one (defined above) which returns the full path to whichever style thumbnail is passed in.
      # In a pinch, you can either use +read_attribute+ or the plain +foo+ accessor, which returns the database's
      # +foo_file_name+ column.
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
        options = DEFAULT_ATTACHMENT_OPTIONS.merge(options)

        include InstanceMethods
        attachments ||= {}

        attachment_names.each do |attr|
          attachments[attr] = (attachments[attr] || {:name => attr}).merge(options)

          define_method "#{attr}=" do |uploaded_file|
            return unless is_a_file? uploaded_file
            attachments[attr].merge!({
              :dirty        => true,
              :files        => {:original => uploaded_file},
              :content_type => uploaded_file.content_type,
              :filename     => sanitize_filename(uploaded_file.original_filename),
              :errors       => []
            })
            write_attribute(:"#{attr}_file_name", attachments[attr][:filename])
            write_attribute(:"#{attr}_content_type", attachments[attr][:content_type])
            
            if attachments[attr][:attachment_type] == :image
              attachments[attr][:thumbnails].each do |style, geometry|
                begin
                  attachments[attr][:files][style] = make_thumbnail(attachments[attr], attachments[attr][:files][:original], geometry)
                rescue PaperclipError => e
                  attachments[attr][:errors] << "thumbnail '#{style}' could not be created."
                end
              end
            end

            uploaded_file
          end
          
          define_method attr do
            read_attribute("#{attr}_file_name")
          end
          alias_method "#{attr}?", attr
          
          define_method "#{attr}_attachment" do
            attachments[attr]
          end
          private "#{attr}_attachment"
          
          define_method "#{attr}_file_name" do |*args|
            style = args.shift || attachments[attr][:default_style] # This prevents arity warnings
            path_for(attachments[attr], style) || interpolate(attachments[attr], attachments[attr][:missing_path], style)
          end
          
          define_method "#{attr}_url" do |*args|
            style = args.shift || attachments[attr][:default_style] # This prevents arity warnings
            url_for(attachments[attr], style) || interpolate(attachments[attr], attachments[attr][:missing_url], style)
          end
          
          define_method "#{attr}_valid?" do
            attachments[attr][:thumbnails].all? do |style, geometry|
              attachments[attr][:dirty] ?
                !attachments[attr][:files][style].blank? && attachments[attr][:errors].empty? :
                File.file?( path_for(attachments[attr], style))
            end
          end
          
          define_method "destroy_#{attr}" do |*args|
            complain = args.first || false
            if attachments[attr].keys.any?
              delete_attachment attachments[attr], complain
            end
          end
          
          # alias_method_chain :save, :paperclip
          
          validates_each attr do |r, a, v|
            attachments[attr][:errors].each{|e| r.errors.add(attr, e) } if attachments[attr][:errors]
          end

          define_method "#{attr}_before_save" do
            if attachments[attr].keys.any?
              write_attachment attachments[attr] if attachments[attr][:files]
              attachments[attr][:dirty] = false
              attachments[attr][:files] = nil
            end
          end
          private :"#{attr}_before_save"
          after_save :"#{attr}_before_save"
          
          define_method "#{attr}_before_destroy" do
            if attachments[attr].keys.any?
              delete_attachment attachments[attr] if attachments[attr][:delete_on_destroy]
            end
          end
          private :"#{attr}_before_destroy"
          before_destroy :"#{attr}_before_destroy"
        end
      end
    end

    module InstanceMethods #:nodoc:
      
      def save_with_paperclip perform_validations = true
        begin
          save_without_paperclip(perform_validations)
        rescue PaperclipError => e
          self.errors.add(e.attachment, "could not be saved because of #{e.reason}")
          false
        end
      end
      
      private
      
      def interpolate attachment, source, style
        file_name = read_attribute("#{attachment[:name]}_file_name")
        returning source.dup do |s|
          s.gsub!(/:rails_root/, RAILS_ROOT)
          s.gsub!(/:id/, self.id.to_s) if self.id
          s.gsub!(/:class/, self.class.to_s.underscore.pluralize)
          s.gsub!(/:style/, style.to_s)
          s.gsub!(/:attachment/, attachment[:name].to_s.pluralize)
          s.gsub!(/:name/, file_name) if file_name
        end
      end
      
      def path_for attachment, style = nil
        style ||= attachment[:default_style]
        file = read_attribute("#{attachment[:name]}_file_name")
        return nil unless file && self.id
         
        prefix = interpolate attachment, "#{attachment[:path_prefix]}/#{attachment[:path]}", style
        File.join( prefix.split("/") )
      end
      
      def url_for attachment, style = nil
        style ||= attachment[:default_style]
        file = read_attribute("#{attachment[:name]}_file_name")
        return nil unless file && self.id
         
        interpolate attachment, "#{attachment[:url_prefix]}/#{attachment[:path]}", style
      end
      
      def ensure_directories_for attachment
        attachment[:files].each do |style, file|
          dirname = File.dirname(path_for(attachment, style))
          FileUtils.mkdir_p dirname
        end
      end
      
      def write_attachment attachment
        ensure_directories_for attachment
        attachment[:files].each do |style, atch|
          File.open( path_for(attachment, style), "w" ) do |file|
            atch.rewind
            file.write(atch.read)
          end
        end
      end
      
      def delete_attachment attachment, complain = false
        (attachment[:thumbnails].keys + [:original]).each do |style|
          file_path = path_for(attachment, style)
          begin
            FileUtils.rm file_path if file_path
          rescue SystemCallError => e
            raise PaperclipError(attachment[:name], e.message, e) if ::Thoughtbot::Paperclip.options[:whiny_deletes] || complain
          end
        end
        self.update_attribute "#{attachment[:name]}_file_name", nil
        self.update_attribute "#{attachment[:name]}_content_type", nil
      end

      def make_thumbnail attachment, orig_io, geometry
        operator = geometry[-1,1]
        geometry, crop_geometry = geometry_for_crop(geometry, orig_io) if operator == '#'
        begin
          command = "convert - -scale '#{geometry}' #{operator == '#' ? "-crop '#{crop_geometry}'" : ""} -"
          ActiveRecord::Base.logger.info("Thumbnail: '#{command}'")
          thumb = IO.popen(command, "w+") do |io|
            orig_io.rewind
            io.write(orig_io.read)
            io.close_write
            StringIO.new(io.read)
          end
        rescue Errno::EPIPE => e
          raise PaperclipError.new(attachment, "Could not create thumbnail. Is ImageMagick or GraphicsMagick installed and available?", e)
        rescue SystemCallError => e
          raise PaperclipError.new(attachment, "Could not create thumbnail.", e)
        end
        if ::Thoughtbot::Paperclip.options[:whiny_thumbnails]
          raise PaperclipError.new(attachment, "Convert returned with result code #{$?.exitstatus}: #{thumb.read}") unless $?.success?
        end
        thumb
      end
      
      def geometry_for_crop geometry, orig_io
        IO.popen("identify -", "w+") do |io|
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
      
      def is_a_file? data
        [:size, :content_type, :original_filename, :read].map do |meth|
          data.respond_to? meth
        end.all?
      end

      def sanitize_filename filename
        File.basename(filename).gsub(/[^\w\.\_]/,'_')
      end
      protected :sanitize_filename
    end
    
    # The Upfile module is a convenience module for adding uploaded-file-type methods
    # to the +File+ class. Useful for testing.
    #   user.avatar = File.new("test/test_avatar.jpg")
    module Upfile
      # Infer the MIME-type of the file from the extension.
      def content_type
        type = self.path.match(/\.(\w+)$/)[1]
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
end
