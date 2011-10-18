module Paperclip
  module Storage
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
    #   http://docs.amazonwebservices.com/AmazonS3/latest/dev/index.html?RESTAccessPolicy.html)
    #   The default for Paperclip is :public_read.
    #
    #   You can set permission on a per style bases by doing the following:
    #     :s3_permissions => {
    #       :original => :private
    #     }
    #   Or globaly:
    #     :s3_permissions => :private
    #
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
    # * +url+: There are four options for the S3 url. You can choose to have the bucket's name
    #   placed domain-style (bucket.s3.amazonaws.com) or path-style (s3.amazonaws.com/bucket).
    #   You can also specify a CNAME (which requires the CNAME to be specified as
    #   :s3_alias_url. You can read more about CNAMEs and S3 at
    #   http://docs.amazonwebservices.com/AmazonS3/latest/index.html?VirtualHosting.html
    #   Normally, this won't matter in the slightest and you can leave the default (which is
    #   path-style, or :s3_path_url). But in some cases paths don't work and you need to use
    #   the domain-style (:s3_domain_url). Anything else here will be treated like path-style.
    #   NOTE: If you use a CNAME for use with CloudFront, you can NOT specify https as your
    #   :s3_protocol; This is *not supported* by S3/CloudFront. Finally, when using the host
    #   alias, the :bucket parameter is ignored, as the hostname is used as the bucket name
    #   by S3. The fourth option for the S3 url is :asset_host, which uses Rails' built-in
    #   asset_host settings. NOTE: To get the full url from a paperclip'd object, use the
    #   image_path helper; this is what image_tag uses to generate the url for an img tag.
    # * +path+: This is the key under the bucket in which the file will be stored. The
    #   URL will be constructed from the bucket and the path. This is what you will want
    #   to interpolate. Keys should be unique, like filenames, and despite the fact that
    #   S3 (strictly speaking) does not support directories, you can still use a / to
    #   separate parts of your file name.
    # * +s3_host_name+: If you are using your bucket in Tokyo region etc, write host_name.
    module S3
      def self.extended base
        begin
          require 'aws/s3'
        rescue LoadError => e
          e.message << " (You may need to install the aws-s3 gem)"
          raise e
        end unless defined?(AWS::S3)

        base.instance_eval do
          @s3_options     = @options.s3_options     || {}
          @s3_permissions = set_permissions(@options.s3_permissions)
          @s3_protocol    = @options.s3_protocol    ||
            Proc.new do |style|
              (@s3_permissions[style.to_sym] || @s3_permissions[:default]) == :public_read ? 'http' : 'https'
            end
          @s3_headers     = @options.s3_headers     || {}

          unless @options.url.to_s.match(/^:s3.*url$/) || @options.url == ":asset_host"
            @options.path         = @options.path.gsub(/:url/, @options.url).gsub(/^:rails_root\/public\/system/, '')
            @options.url          = ":s3_path_url"
          end
          @options.url = @options.url.inspect if @options.url.is_a?(Symbol)

          @http_proxy = @options.http_proxy || nil
          if @http_proxy
            @s3_options.merge!({:proxy => @http_proxy})
          end

          AWS::S3::Base.establish_connection!( @s3_options.merge(
            :access_key_id => s3_credentials[:access_key_id],
            :secret_access_key => s3_credentials[:secret_access_key]
          ))
        end
        Paperclip.interpolates(:s3_alias_url) do |attachment, style|
          "#{attachment.s3_protocol(style)}://#{attachment.s3_host_alias}/#{attachment.path(style).gsub(%r{^/}, "")}"
        end unless Paperclip::Interpolations.respond_to? :s3_alias_url
        Paperclip.interpolates(:s3_path_url) do |attachment, style|
          "#{attachment.s3_protocol(style)}://#{attachment.s3_host_name}/#{attachment.bucket_name}/#{attachment.path(style).gsub(%r{^/}, "")}"
        end unless Paperclip::Interpolations.respond_to? :s3_path_url
        Paperclip.interpolates(:s3_domain_url) do |attachment, style|
          "#{attachment.s3_protocol(style)}://#{attachment.bucket_name}.#{attachment.s3_host_name}/#{attachment.path(style).gsub(%r{^/}, "")}"
        end unless Paperclip::Interpolations.respond_to? :s3_domain_url
        Paperclip.interpolates(:asset_host) do |attachment, style|
          "#{attachment.path(style).gsub(%r{^/}, "")}"
        end unless Paperclip::Interpolations.respond_to? :asset_host
      end

      def expiring_url(time = 3600, style_name = default_style)
        AWS::S3::S3Object.url_for(path(style_name), bucket_name, :expires_in => time, :use_ssl => (s3_protocol(style_name) == 'https'))
      end

      def s3_credentials
        @s3_credentials ||= parse_credentials(@options.s3_credentials)
      end

      def s3_host_name
        @options.s3_host_name || s3_credentials[:s3_host_name] || "s3.amazonaws.com"
      end

      def s3_host_alias
        @s3_host_alias = @options.s3_host_alias
        @s3_host_alias = @s3_host_alias.call(self) if @s3_host_alias.is_a?(Proc)
        @s3_host_alias
      end

      def bucket_name
        @bucket = @options.bucket || s3_credentials[:bucket]
        @bucket = @bucket.call(self) if @bucket.is_a?(Proc)
        @bucket
      end

      def using_http_proxy?
        !!@http_proxy
      end

      def http_proxy_host
        using_http_proxy? ? @http_proxy[:host] : nil
      end

      def http_proxy_port
        using_http_proxy? ? @http_proxy[:port] : nil
      end

      def http_proxy_user
        using_http_proxy? ? @http_proxy[:user] : nil
      end

      def http_proxy_password
        using_http_proxy? ? @http_proxy[:password] : nil
      end

      def set_permissions permissions
        if permissions.is_a?(Hash)
          permissions[:default] = permissions[:default] || :public_read
        else
          permissions = { :default => permissions || :public_read }
        end
        permissions
      end

      def parse_credentials creds
        creds = find_credentials(creds).stringify_keys
        env = Object.const_defined?(:Rails) ? Rails.env : nil
        (creds[env] || creds).symbolize_keys
      end

      def exists?(style = default_style)
        if original_filename
          AWS::S3::S3Object.exists?(path(style), bucket_name)
        else
          false
        end
      end

      def s3_protocol(style = default_style)
        if @s3_protocol.is_a?(Proc)
          @s3_protocol.call(style)
        else
          @s3_protocol
        end
      end

      # Returns representation of the data of the file assigned to the given
      # style, in the format most representative of the current storage.
      def to_file style = default_style
        return @queued_for_write[style] if @queued_for_write[style]
        filename = path(style)
        extname  = File.extname(filename)
        basename = File.basename(filename, extname)
        file = Tempfile.new([basename, extname])
        file.binmode
        file.write(AWS::S3::S3Object.value(path(style), bucket_name))
        file.rewind
        return file
      end

      def create_bucket
        AWS::S3::Bucket.create(bucket_name)
      end

      def flush_writes #:nodoc:
        @queued_for_write.each do |style, file|
          begin
            log("saving #{path(style)}")
            AWS::S3::S3Object.store(path(style),
                                    file,
                                    bucket_name,
                                    {:content_type => file.content_type.to_s.strip,
                                     :access => (@s3_permissions[style] || @s3_permissions[:default]),
                                    }.merge(@s3_headers))
          rescue AWS::S3::NoSuchBucket => e
            create_bucket
            retry
          rescue AWS::S3::ResponseError => e
            raise
          end
        end

        after_flush_writes # allows attachment to clean up temp files

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
  end
end
