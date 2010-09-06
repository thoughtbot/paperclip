=======
module Paperclip
  module Storage

    # The default place to store attachments is in the filesystem. Files on the local
    # filesystem can be very easily served by Apache without requiring a hit to your app.
    # They also can be processed more easily after they've been saved, as they're just
    # normal files. There is one Filesystem-specific option for has_attached_file.
    # * +path+: The location of the repository of attachments on disk. This can (and, in
    #   almost all cases, should) be coordinated with the value of the +url+ option to
    #   allow files to be saved into a place where Apache can serve them without
    #   hitting your app. Defaults to
    #   ":rails_root/public/:attachment/:id/:style/:basename.:extension"
    #   By default this places the files in the app's public directory which can be served
    #   directly. If you are using capistrano for deployment, a good idea would be to
    #   make a symlink to the capistrano-created system directory from inside your app's
    #   public directory.
    #   See Paperclip::Attachment#interpolate for more information on variable interpolaton.
    #     :path => "/var/app/attachments/:class/:id/:style/:basename.:extension"
    module Filesystem
      def self.extended base
      end

      def exists?(style_name = default_style)
        if original_filename
          File.exist?(path(style_name))
        else
          false
        end
      end

      # Returns representation of the data of the file assigned to the given
      # style, in the format most representative of the current storage.
      def to_file style_name = default_style
        @queued_for_write[style_name] || (File.new(path(style_name), 'rb') if exists?(style_name))
      end

      def flush_writes #:nodoc:
        @queued_for_write.each do |style_name, file|
          file.close
          FileUtils.mkdir_p(File.dirname(path(style_name)))
          log("saving #{path(style_name)}")
          FileUtils.mv(file.path, path(style_name))
          FileUtils.chmod(0644, path(style_name))
        end
        @queued_for_write = {}
      end

      def flush_deletes #:nodoc:
        @queued_for_delete.each do |path|
          begin
            log("deleting #{path}")
            FileUtils.rm(path) if File.exist?(path)
          rescue Errno::ENOENT => e
            # ignore file-not-found, let everything else pass
          end
          begin
            while(true)
              path = File.dirname(path)
              FileUtils.rmdir(path)
            end
          rescue Errno::EEXIST, Errno::ENOTEMPTY, Errno::ENOENT, Errno::EINVAL, Errno::ENOTDIR
            # Stop trying to remove parent directories
          rescue SystemCallError => e
            log("There was an unexpected error while deleting directories: #{e.class}")
            # Ignore it
          end
        end
        @queued_for_delete = []
      end
    end

    # Amazon's S3 file hosting service is a scalable, easy place to store files for
    # distribution. You can find out more about it at http://aws.amazon.com/s3
    # There are a few S3-specific options for has_attached_file:
    # * +s3_credentials+: Takes a path, a File, or a Hash. The path (or File) must point
    #   to a YAML file containing the +access_key_id+ and +secret_access_key+ that Amazon
    #   gives you. You can 'environment-space' this just like you do to your
    #   database.yml file, so different environments can use different accounts:
    #     development:
    #       access_key_id: 123...
    #       secret_access_key: 123...
    #     test:
    #       access_key_id: abc...
    #       secret_access_key: abc...
    #     production:
    #       access_key_id: 456...
    #       secret_access_key: 456...
    #   This is not required, however, and the file may simply look like this:
    #     access_key_id: 456...
    #     secret_access_key: 456...
    #   In which case, those access keys will be used in all environments. You can also
    #   put your bucket name in this file, instead of adding it to the code directly.
    #   This is useful when you want the same account but a different bucket for
    #   development versus production.
    # * +s3_permissions+: This is a String that should be one of the "canned" access
    #   policies that S3 provides (more information can be found here:
    #   http://docs.amazonwebservices.com/AmazonS3/2006-03-01/RESTAccessPolicy.html#RESTCannedAccessPolicies)
    #   The default for Paperclip is :public_read.
    # * +s3_protocol+: The protocol for the URLs generated to your S3 assets. Can be either
    #   'http' or 'https'. Defaults to 'http' when your :s3_permissions are :public_read (the
    #   default), and 'https' when your :s3_permissions are anything else.
    # * +s3_headers+: A hash of headers such as {'Expires' => 1.year.from_now.httpdate}
    # * +bucket+: This is the name of the S3 bucket that will store your files. Remember
    #   that the bucket must be unique across all of Amazon S3. If the bucket does not exist
    #   Paperclip will attempt to create it. The bucket name will not be interpolated.
    #   You can define the bucket as a Proc if you want to determine it's name at runtime.
    #   Paperclip will call that Proc with attachment as the only argument.
    # * +s3_host_alias+: The fully-qualified domain name (FQDN) that is the alias to the
    #   S3 domain of your bucket. Used with the :s3_alias_url url interpolation. See the
    #   link in the +url+ entry for more information about S3 domains and buckets.
    # * +url+: There are three options for the S3 url. You can choose to have the bucket's name
    #   placed domain-style (bucket.s3.amazonaws.com) or path-style (s3.amazonaws.com/bucket).
    #   Lastly, you can specify a CNAME (which requires the CNAME to be specified as
    #   :s3_alias_url. You can read more about CNAMEs and S3 at
    #   http://docs.amazonwebservices.com/AmazonS3/latest/index.html?VirtualHosting.html
    #   Normally, this won't matter in the slightest and you can leave the default (which is
    #   path-style, or :s3_path_url). But in some cases paths don't work and you need to use
    #   the domain-style (:s3_domain_url). Anything else here will be treated like path-style.
    #   NOTE: If you use a CNAME for use with CloudFront, you can NOT specify https as your
    #   :s3_protocol; This is *not supported* by S3/CloudFront. Finally, when using the host
    #   alias, the :bucket parameter is ignored, as the hostname is used as the bucket name
    #   by S3.
    # * +path+: This is the key under the bucket in which the file will be stored. The
    #   URL will be constructed from the bucket and the path. This is what you will want
    #   to interpolate. Keys should be unique, like filenames, and despite the fact that
    #   S3 (strictly speaking) does not support directories, you can still use a / to
    #   separate parts of your file name.
    module S3
      def self.extended base
        begin
          require 'aws/s3'
        rescue LoadError => e
          e.message << " (You may need to install the aws-s3 gem)"
          raise e
        end

        base.instance_eval do
          @s3_credentials = parse_credentials(@options[:s3_credentials])
          @bucket         = @options[:bucket]         || @s3_credentials[:bucket]
          @bucket         = @bucket.call(self) if @bucket.is_a?(Proc)
          @s3_options     = @options[:s3_options]     || {}
          @s3_permissions = @options[:s3_permissions] || :public_read
          @s3_protocol    = @options[:s3_protocol]    || (@s3_permissions == :public_read ? 'http' : 'https')
          @s3_headers     = @options[:s3_headers]     || {}
          @s3_host_alias  = @options[:s3_host_alias]
          @url            = ":s3_path_url" unless @url.to_s.match(/^:s3.*url$/)
          AWS::S3::Base.establish_connection!( @s3_options.merge(
            :access_key_id => @s3_credentials[:access_key_id],
            :secret_access_key => @s3_credentials[:secret_access_key]
          ))
        end
        Paperclip.interpolates(:s3_alias_url) do |attachment, style|
          "#{attachment.s3_protocol}://#{attachment.s3_host_alias}/#{attachment.path(style).gsub(%r{^/}, "")}"
        end
        Paperclip.interpolates(:s3_path_url) do |attachment, style|
          "#{attachment.s3_protocol}://s3.amazonaws.com/#{attachment.bucket_name}/#{attachment.path(style).gsub(%r{^/}, "")}"
        end
        Paperclip.interpolates(:s3_domain_url) do |attachment, style|
          "#{attachment.s3_protocol}://#{attachment.bucket_name}.s3.amazonaws.com/#{attachment.path(style).gsub(%r{^/}, "")}"
        end
      end

      def expiring_url(time = 3600)
        AWS::S3::S3Object.url_for(path, bucket_name, :expires_in => time )
      end

      def bucket_name
        @bucket
      end

      def s3_host_alias
        @s3_host_alias
      end

      def parse_credentials creds
        creds = find_credentials(creds).stringify_keys
        (creds[Rails.env] || creds).symbolize_keys
      end

      def exists?(style = default_style)
        if original_filename
          AWS::S3::S3Object.exists?(path(style), bucket_name)
        else
          false
        end
      end

      def s3_protocol
        @s3_protocol
      end

      # Returns representation of the data of the file assigned to the given
      # style, in the format most representative of the current storage.
      def to_file style = default_style
        return @queued_for_write[style] if @queued_for_write[style]
        file = Tempfile.new(path(style))
        file.write(AWS::S3::S3Object.value(path(style), bucket_name))
        file.rewind
        return file
      end

      def flush_writes #:nodoc:
        @queued_for_write.each do |style, file|
          begin
            log("saving #{path(style)}")
            AWS::S3::S3Object.store(path(style),
                                    file,
                                    bucket_name,
                                    {:content_type => instance_read(:content_type),
                                     :access => @s3_permissions,
                                    }.merge(@s3_headers))
          rescue AWS::S3::ResponseError => e
            raise
          end
        end
        @queued_for_write = {}
      end

      def flush_deletes #:nodoc:
        @queued_for_delete.each do |path|
          begin
            log("deleting #{path}")
            AWS::S3::S3Object.delete(path, bucket_name)
          rescue AWS::S3::ResponseError
            # Ignore this.
          end
        end
        @queued_for_delete = []
      end

      def find_credentials creds
        case creds
        when File
          YAML::load(ERB.new(File.read(creds.path)).result)
        when String, Pathname
          YAML::load(ERB.new(File.read(creds)).result)
        when Hash
          creds
        else
          raise ArgumentError, "Credentials are not a path, file, or hash."
        end
      end
      private :find_credentials

    end

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
            @url = ":relative_root/:class/:attachment/:id?style=:style"
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
