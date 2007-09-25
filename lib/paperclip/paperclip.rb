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
      :whiny_deletes     => false,
      :whiny_thumbnails  => true,
      :image_magick_path => nil
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
      #   if it has had the +Upfile+ module included. +file+ can also be a URL object pointing to a valid
      #   resource. This resource will be downloaded using +open-uri+[http://www.ruby-doc.org/stdlib/libdoc/open-uri/rdoc/]
      #   and processed as a regular file object would. Finally, you can set this property to +nil+ to clear
      #   the attachment, which is the same thing as calling +destroy_attachment+.
      #   Note this does not save the attachments.
      #     user.avatar = File.new("~/pictures/me.png")
      #     user.avatar = params[:user][:avatar] # When :avatar is a file_field
      #     user.avatar = URI.parse("http://www.avatars-r-us.com/spiffy.png")
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
      # * destroy_attachment(complain = false): Flags the attachment and all thumbnails for deletion. Sets
      #   the +attachment_file_name+ column and +attachment_content_type+ column to +nil+. Set +complain+
      #   to true to override the +whiny_deletes+ option. NOTE: this does not actually delete the attachment.
      #   You must still call +save+ on the model to actually delete the file and commit the change to the
      #   database.
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
      # * +base+: The base of the file's name, e.g. "myself" from "myself.jpg", or "my.picture" from "my.picture.png".
      #   It is defined as everything except the final period and what follows it. If there is no extension, :base works
      #   the same as :name.
      # * +ext+: The extension of the file, e.g. "jpg" from "myself.jpg". It is defined as everything following the final
      #   period
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
      # Note that if these columns are not found in the model (according to +ActiveRecord::Base#column_names+) then
      # Paperclip will throw a +PaperclipError+ informing you of the fact.
      #
      # == Event Triggers
      # When an attachment is set by using he setter (+model.attachment=+), the thumbnails are created and held in
      # memory. They are not saved until the +after_save+ trigger fires, at which point the attachment and all
      # thumbnails are written to disk.
      #
      # Attached files are destroyed when the associated record is destroyed in a +before_destroy+ trigger. Set
      # the +delete_on_destroy+ option to +false+ to prevent this behavior. Also note that using the ActiveRecord's
      # +delete+ method instead of the +destroy+ method will prevent the +before_destroy+ trigger from firing.
      #
      # == Validation
      # If there is a problem in the thumbnail-making process, Paperclip will add errors to your model on save. These
      # errors appear if there is an error with +convert+ (e.g. +convert+ doesn't exist, the file wasn't an image, etc).
      def has_attached_file *attachment_names
        options = attachment_names.last.is_a?(Hash) ? attachment_names.pop : {}
        options = DEFAULT_ATTACHMENT_OPTIONS.merge(options)

        include InstanceMethods
        attachments = (@attachments ||= {})

        define_method :after_initialize do
          attachments.each do |name, options|
            options[:instance] = self
          end
        end

        attachment_names.each do |attr|
          attachments[attr] = (attachments[attr] || {:name => attr}).merge(options)
          whine_about_columns_for attachments[attr]
            
          if attachments[attr][:storage]
            attachments[attr][:storage] = Thoughtbot::Paperclip::Storage.const_get(attachments[attr][:storage].to_s.camelize).new
          else
            attachments[attr][:storage] = Thoughtbot::Paperclip::Storage::Filesystem.new
          end

          define_method "#{attr}=" do |uploaded_file|
            uploaded_file = fetch_uri(uploaded_file) if uploaded_file.is_a? URI
            return send("destroy_#{attr}") if uploaded_file.nil?
            return unless is_a_file? uploaded_file
            
            attachments[attr].merge!({
              :dirty          => true,
              :files          => {:original => uploaded_file},
              :content_type   => uploaded_file.content_type,
              :file_name      => sanitize_filename(uploaded_file.original_filename),
              :errors         => [],
              :delete_on_save => false
            })
            write_attribute(:"#{attr}_file_name", attachments[attr][:file_name])
            write_attribute(:"#{attr}_content_type", attachments[attr][:content_type])
            
            if attachments[attr][:attachment_type] == :image
              send("process_#{attr}_thumbnails")
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
          private :"#{attr}_attachment"
          
          define_method "#{attr}_file_name" do |*args|
            style = args.shift || attachments[attr][:default_style] # This prevents arity warnings
            attachments[attr][:storage].path_for(attachments[attr], style) ||
            attachments[attr][:storage].interpolate(attachments[attr], attachments[attr][:missing_path], style)
          end
          
          define_method "#{attr}_url" do |*args|
            style = args.shift || attachments[attr][:default_style] # This prevents arity warnings
            attachments[attr][:storage].url_for(attachments[attr], style) ||
            attachments[attr][:storage].interpolate(attachments[attr], attachments[attr][:missing_url], style)
          end
          
          define_method "#{attr}_valid?" do
            attachments[attr][:storage].attachment_valid? attachments[attr]
          end
          
          define_method "process_#{attr}_thumbnails" do
            attachments[attr][:storage].make_thumbnails attachments[attr]
          end
          
          define_method "destroy_#{attr}" do |*args|
            complain = args.first || false
            if attachments[attr].keys.any?
              attachments[attr][:files] = nil
              attachments[attr][:delete_on_save] = true
              attachments[attr][:complain_on_delete] = complain
              write_attribute("#{attr}_file_name", nil)
              write_attribute("#{attr}_content_type", nil)
            end
            true
          end
          
          validates_each attr do |r, a, v|
            attachments[attr][:errors].each{|e| r.errors.add(attr, e) } if attachments[attr][:errors]
          end

          define_method "#{attr}_before_save" do
            if attachments[attr].keys.any?
              if attachments[attr][:files]
                attachments[attr][:storage].write_attachment attachments[attr] 
              end
              if attachments[attr][:delete_on_save]
                attachments[attr][:storage].delete_attachment attachments[attr], attachments[attr][:complain_on_delete] 
              end
              attachments[attr][:delete_on_save] = false
              attachments[attr][:dirty] = false
              attachments[attr][:files] = nil
            end
          end
          private :"#{attr}_before_save"
          after_save :"#{attr}_before_save"
          
          define_method "#{attr}_before_destroy" do
            if attachments[attr].keys.any?
              attachments[attr][:storage].delete_attachment attachments[attr] if attachments[attr][:delete_on_destroy]
            end
          end
          private :"#{attr}_before_destroy"
          before_destroy :"#{attr}_before_destroy"
        end
        
        [attachments, options]
      end
      
      def attachment_names
        @attachments.keys
      end
      
      def attachment name
        @attachments[name]
      end
      
      # Adds errors if the attachments you specify are either missing or had errors on them.
      # Essentially, acts like validates_presence_of for attachments.
      def validates_attached_file *attachment_names
        validates_each *attachment_names do |r, a, v|
          r.errors.add(a, "requires a valid attachment.") unless r.send("#{a}_valid?")
        end
      end
      
      def whine_about_columns_for attachment #:nodoc:
        name = attachment[:name]
        unless column_names.include?("#{name}_file_name") && column_names.include?("#{name}_content_type")
          error = "Class #{self.name} does not have the necessary columns to have an attachment named #{name}. " +
                  "(#{name}_file_name and #{name}_content_type)"
          raise PaperclipError.new(attachment), error
        end
      end
    end

    module InstanceMethods #:nodoc:
      def is_a_file? data
        [:content_type, :original_filename, :read].map do |meth|
          data.respond_to? meth
        end.all?
      end

      def sanitize_filename filename
        File.basename(filename).gsub(/[^\w\.\_]/,'_')
      end
      
      def fetch_uri uri
        image = if uri.scheme == 'file'
          path = url.gsub(%r{^file://}, '/')
          open(path)
        else
          require 'open-uri'
          uri
        end
        begin
          data = StringIO.new(image.read)
          uri.extend(Upfile)
          class << data
            attr_accessor :original_filename, :content_type
          end
          data.original_filename = uri.original_filename
          data.content_type = uri.content_type
          data
        rescue OpenURI::HTTPError => e
          self.errors.add_to_base("The file at #{uri.to_s} could not be found.")
          $stderr.puts "#{e.message}: #{uri.to_s}"
          return nil
        end
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
end
