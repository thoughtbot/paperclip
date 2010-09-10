module Paperclip
  module Storage

    # Store files in a database.
    # 
    # Usage is identical to the file system storage version, except:
    # 
    # 1. In your model specify the "database" storage option; for example:
    #   has_attached_file :avatar, :storage => :database
    # 
    # 2. The file will be stored in a column called [attachment name]_file (e.g. "avatar_file") by default.
    # 
    # To specify a different column name, use :column, like this:
    #   has_attached_file :avatar, :storage => :database, :column => 'avatar_data'
    # 
    # If you have defined different styles, these files will be stored in additional columns called
    # [attachment name]_[style name]_file (e.g. "avatar_thumb_file") by default.
    # 
    # To specify different column names for styles, use :column in the style definition, like this:
    #   has_attached_file :avatar,
    #                     :storage => :database,
    #                     :styles => { 
    #                       :medium => {:geometry => "300x300>", :column => 'medium_file'},
    #                       :thumb => {:geometry => "100x100>", :column => 'thumb_file'}
    #                     }
    # 
    # 3. You need to create these new columns in your migrations or you'll get an exception. Example:
    #   add_column :users, :avatar_file, :binary
    #   add_column :users, :avatar_medium_file, :binary
    #   add_column :users, :avatar_thumb_file, :binary
    # 
    # Note the "binary" migration will not work for the LONGBLOB type in MySQL for the
    # file_contents column. You may need to craft a SQL statement for your migration,
    # depending on which database server you are using. Here's an example migration for MySQL:
    #   execute 'ALTER TABLE users ADD COLUMN avatar_file LONGBLOB'
    #   execute 'ALTER TABLE users ADD COLUMN avatar_medium_file LONGBLOB'
    #   execute 'ALTER TABLE users ADD COLUMN avatar_thumb_file LONGBLOB'
    # 
    # 4. To avoid performance problems loading all of the BLOB columns every time you access
    # your ActiveRecord object, a class method is provided on your model called
    # “select_without_file_columns_for.” This is set to a :select scope hash that will
    # instruct ActiveRecord::Base.find to load all of the columns except the BLOB/file data columns.
    # 
    # If you’re using Rails 2.3, you can specify this as a default scope:
    #   default_scope select_without_file_columns_for(:avatar)
    # 
    # Or if you’re using Rails 2.1 or 2.2 you can use it to create a named scope:
    #   named_scope :without_file_data, select_without_file_columns_for(:avatar)
    # 
    # 5. By default, URLs will be set to this pattern:
    #   /:relative_root/:class/:attachment/:id?style=:style
    # 
    # Example:
    #   /app-root-url/users/avatars/23?style=original
    # 
    # The idea here is that to retrieve a file from the database storage, you will need some
    # controller's code to be executed.
    #     
    # Once you pick a controller to use for downloading, you can add this line
    # to generate the download action for the default URL/action (the plural attachment name),
    # "avatars" in this example:
    #   downloads_files_for :user, :avatar
    # 
    # Or you can write a download method manually if there are security, logging or other
    # requirements.
    # 
    # If you prefer a different URL for downloading files you can specify that in the model; e.g.:
    #   has_attached_file :avatar, :storage => :database, :url => '/users/show_avatar/:id/:style'
    # 
    # 6. Add a route for the download to the controller which will handle downloads, if necessary.
    # 
    # The default URL, /:relative_root/:class/:attachment/:id?style=:style, will be matched by
    # the default route: :controller/:action/:id
    # 
    module Database
      def self.extended base
        base.instance_eval do
          @file_columns = @options[:file_columns]
          if @url == base.class.default_options[:url]
            @url = "/:class/:attachment/:id?style=:style"
          end
        end
        Paperclip.interpolates(:relative_root) do |attachment, style|
          begin
            if ActionController::AbstractRequest.respond_to?(:relative_url_root)
              relative_url_root = ActionController::AbstractRequest.relative_url_root
            end
          rescue NameError
          end
          if !relative_url_root && ActionController::Base.respond_to?(:relative_url_root)
            relative_url_root = ActionController::Base.relative_url_root
          end
          relative_url_root
        end
        ActiveRecord::Base.logger.info("[paperclip] Database Storage Initalized.")
      end

      def column_for_style style
        @file_columns[style.to_sym]
      end
        
      def instance_read_file(style)
        column = column_for_style(style)
        responds = instance.respond_to?(column)
        cached = self.instance_variable_get("@_#{column}")
        return cached if cached
        # The blob attribute will not be present if select_without_file_columns_for was used
        instance.reload :select => column if !instance.attribute_present?(column) && !instance.new_record?
        instance.send(column) if responds
      end

      def instance_write_file(style, value)
        setter = :"#{column_for_style(style)}="
        responds = instance.respond_to?(setter)
        self.instance_variable_set("@_#{setter.to_s.chop}", value)
        instance.send(setter, value) if responds
      end

      def file_contents(style = default_style)
        instance_read_file(style)
      end
      alias_method :data, :file_contents

      def exists?(style = default_style)
        !file_contents(style).nil?
      end

      # Returns representation of the data of the file assigned to the given
      # style, in the format most representative of the current storage.
      def to_file style = default_style

        if @queued_for_write[style]
          @queued_for_write[style]
        elsif exists?(style)
          tempfile = Tempfile.new instance_read(:file_name)
          tempfile.write file_contents(style)
          tempfile
        else
          nil
        end
      end
      alias_method :to_io, :to_file

      def path style = default_style
        original_filename.nil? ? nil : column_for_style(style)
      end

      def assign uploaded_file

        # Assign standard metadata attributes and perform post processing as usual
        super

        # Save the file contents for all styles in ActiveRecord immediately (before save)
        @queued_for_write.each do |style, file|
          file.rewind
          instance_write_file(style, file.read)
        end

        # If we are assigning another Paperclip attachment, then fixup the
        # filename and content type; necessary since Tempfile is used in to_file
        if uploaded_file.is_a?(Paperclip::Attachment)
          instance_write(:file_name,       uploaded_file.instance_read(:file_name))
          instance_write(:content_type,    uploaded_file.instance_read(:content_type))
        end
      end

      def queue_existing_for_delete
        [:original, *@styles.keys].uniq.each do |style|
          instance_write_file(style, nil)
        end
        instance_write(:file_name, nil)
        instance_write(:content_type, nil)
        instance_write(:file_size, nil)
        instance_write(:updated_at, nil)
      end

      def flush_writes
        @queued_for_write = {}
      end

      def flush_deletes
        @queued_for_delete = []
      end
      
      module ControllerClassMethods
        def self.included(base)
          base.extend(self)
        end
        def downloads_files_for(model, attachment)
          define_method("#{attachment.to_s.pluralize}") do
            model_record = Object.const_get(model.to_s.camelize.to_sym).find(params[:id])
            style = params[:style] ? params[:style] : 'original'
            send_data model_record.send(attachment).file_contents(style),
                      :filename => model_record.send("#{attachment}_file_name".to_sym),
                      :type => model_record.send("#{attachment}_content_type".to_sym)
          end
        end
      end
    end

  end
end
