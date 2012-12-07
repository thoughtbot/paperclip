module Paperclip
  module Storage
    # Amazon's S3 file hosting service is a scalable, easy place to store files for
    # distribution. You can find out more about it at http://aws.amazon.com/s3
    #
    # To use Paperclip with S3, include the +aws-sdk+ gem in your Gemfile:
    #   gem 'aws-sdk'
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
    #   Or globally:
    #     :s3_permissions => :private
    #
    # * +s3_protocol+: The protocol for the URLs generated to your S3 assets. Can be either
    #   'http', 'https', or an empty string to generate scheme-less URLs. Defaults to 'http'
    #   when your :s3_permissions are :public_read (the default), and 'https' when your
    #   :s3_permissions are anything else.
    # * +s3_headers+: A hash of headers or a Proc. You may specify a hash such as
    #   {'Expires' => 1.year.from_now.httpdate}. If you use a Proc, headers are determined at
    #   runtime. Paperclip will call that Proc with attachment as the only argument.
    #   Can be defined both globally and within a style-specific hash.
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
    #
    #   Notes:
    #   * The value of this option is a string, not a symbol.
    #     <b>right:</b> <tt>":s3_domain_url"</tt>
    #     <b>wrong:</b> <tt>:s3_domain_url</tt>
    #   * If you use a CNAME for use with CloudFront, you can NOT specify https as your
    #     :s3_protocol;
    #     This is *not supported* by S3/CloudFront. Finally, when using the host
    #     alias, the :bucket parameter is ignored, as the hostname is used as the bucket name
    #     by S3. The fourth option for the S3 url is :asset_host, which uses Rails' built-in
    #     asset_host settings.
    #   * To get the full url from a paperclip'd object, use the
    #     image_path helper; this is what image_tag uses to generate the url for an img tag.
    # * +path+: This is the key under the bucket in which the file will be stored. The
    #   URL will be constructed from the bucket and the path. This is what you will want
    #   to interpolate. Keys should be unique, like filenames, and despite the fact that
    #   S3 (strictly speaking) does not support directories, you can still use a / to
    #   separate parts of your file name.
    # * +s3_host_name+: If you are using your bucket in Tokyo region etc, write host_name.
    # * +s3_metadata+: These key/value pairs will be stored with the
    #   object.  This option works by prefixing each key with
    #   "x-amz-meta-" before sending it as a header on the object
    #   upload request. Can be defined both globally and within a style-specific hash.
    # * +s3_storage_class+: If this option is set to
    #   <tt>:reduced_redundancy</tt>, the object will be stored using Reduced
    #   Redundancy Storage.  RRS enables customers to reduce their
    #   costs by storing non-critical, reproducible data at lower
    #   levels of redundancy than Amazon S3's standard storage.
    module S3
      def self.extended base
        begin
          require 'aws-sdk'
        rescue LoadError => e
          e.message << " (You may need to install the aws-sdk gem)"
          raise e
        end unless defined?(AWS::Core)

        # Overriding AWS::Core::LogFormatter to make sure it return a UTF-8 string
        if AWS::VERSION >= "1.3.9"
          AWS::Core::LogFormatter.class_eval do
            def summarize_hash(hash)
              hash.map { |key, value| ":#{key}=>#{summarize_value(value)}".force_encoding('UTF-8') }.sort.join(',')
            end
          end
        else
          AWS::Core::ClientLogging.class_eval do
            def sanitize_hash(hash)
              hash.map { |key, value| "#{sanitize_value(key)}=>#{sanitize_value(value)}".force_encoding('UTF-8') }.sort.join(',')
            end
          end
        end

        base.instance_eval do
          @s3_options     = @options[:s3_options]     || {}
          @s3_permissions = set_permissions(@options[:s3_permissions])
          @s3_protocol    = @options[:s3_protocol]    ||
            Proc.new do |style, attachment|
              permission  = (@s3_permissions[style.to_s.to_sym] || @s3_permissions[:default])
              permission  = permission.call(attachment, style) if permission.respond_to?(:call)
              (permission == :public_read) ? 'http' : 'https'
            end
          @s3_metadata = @options[:s3_metadata] || {}
          @s3_headers = {}
          merge_s3_headers(@options[:s3_headers], @s3_headers, @s3_metadata)

          @s3_headers[:storage_class] = @options[:s3_storage_class] if @options[:s3_storage_class]

          @s3_server_side_encryption = :aes256
          if @options[:s3_server_side_encryption].blank?
            @s3_server_side_encryption = false
          end
          if @s3_server_side_encryption
            @s3_server_side_encryption = @options[:s3_server_side_encryption].to_s.upcase
          end

          unless @options[:url].to_s.match(/^:s3.*url$/) || @options[:url] == ":asset_host"
            @options[:path] = @options[:path].gsub(/:url/, @options[:url]).gsub(/^:rails_root\/public\/system/, '')
            @options[:url]  = ":s3_path_url"
          end
          @options[:url] = @options[:url].inspect if @options[:url].is_a?(Symbol)

          @http_proxy = @options[:http_proxy] || nil
        end

        Paperclip.interpolates(:s3_alias_url) do |attachment, style|
          "#{attachment.s3_protocol(style, true)}//#{attachment.s3_host_alias}/#{attachment.path(style).gsub(%r{^/}, "")}"
        end unless Paperclip::Interpolations.respond_to? :s3_alias_url
        Paperclip.interpolates(:s3_path_url) do |attachment, style|
          "#{attachment.s3_protocol(style, true)}//#{attachment.s3_host_name}/#{attachment.bucket_name}/#{attachment.path(style).gsub(%r{^/}, "")}"
        end unless Paperclip::Interpolations.respond_to? :s3_path_url
        Paperclip.interpolates(:s3_domain_url) do |attachment, style|
          "#{attachment.s3_protocol(style, true)}//#{attachment.bucket_name}.#{attachment.s3_host_name}/#{attachment.path(style).gsub(%r{^/}, "")}"
        end unless Paperclip::Interpolations.respond_to? :s3_domain_url
        Paperclip.interpolates(:asset_host) do |attachment, style|
          "#{attachment.path(style).gsub(%r{^/}, "")}"
        end unless Paperclip::Interpolations.respond_to? :asset_host
      end

      def expiring_url(time = 3600, style_name = default_style)
        if path
          base_options = { :expires => time, :secure => use_secure_protocol?(style_name) }
          s3_object(style_name).url_for(:read, base_options.merge(s3_url_options)).to_s
        end
      end

      def s3_credentials
        @s3_credentials ||= parse_credentials(@options[:s3_credentials])
      end

      def s3_host_name
        @options[:s3_host_name] || s3_credentials[:s3_host_name] || "s3.amazonaws.com"
      end

      def s3_host_alias
        @s3_host_alias = @options[:s3_host_alias]
        @s3_host_alias = @s3_host_alias.call(self) if @s3_host_alias.respond_to?(:call)
        @s3_host_alias
      end

      def s3_url_options
        s3_url_options = @options[:s3_url_options] || {}
        s3_url_options = s3_url_options.call(instance) if s3_url_options.respond_to?(:call)
        s3_url_options
      end

      def bucket_name
        @bucket = @options[:bucket] || s3_credentials[:bucket]
        @bucket = @bucket.call(self) if @bucket.respond_to?(:call)
        @bucket or raise ArgumentError, "missing required :bucket option"
      end

      def s3_interface
        @s3_interface ||= begin
          config = { :s3_endpoint => s3_host_name }

          if using_http_proxy?

            proxy_opts = { :host => http_proxy_host }
            proxy_opts[:port] = http_proxy_port if http_proxy_port
            if http_proxy_user
              userinfo = http_proxy_user.to_s
              userinfo += ":#{http_proxy_password}" if http_proxy_password
              proxy_opts[:userinfo] = userinfo
            end
            config[:proxy_uri] = URI::HTTP.build(proxy_opts)
          end

          [:access_key_id, :secret_access_key].each do |opt|
            config[opt] = s3_credentials[opt] if s3_credentials[opt]
          end

          obtain_s3_instance_for(config.merge(@s3_options))
        end
      end

      def obtain_s3_instance_for(options)
        instances = (Thread.current[:paperclip_s3_instances] ||= {})
        instances[options] ||= AWS::S3.new(options)
      end

      def s3_bucket
        @s3_bucket ||= s3_interface.buckets[bucket_name]
      end

      def s3_object style_name = default_style
        s3_bucket.objects[path(style_name).sub(%r{^/},'')]
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
        permissions = { :default => permissions } unless permissions.respond_to?(:merge)
        permissions.merge :default => (permissions[:default] || :public_read)
      end

      def parse_credentials creds
        creds = creds.respond_to?('call') ? creds.call(self) : creds
        creds = find_credentials(creds).stringify_keys
        env = Object.const_defined?(:Rails) ? Rails.env : nil
        (creds[env] || creds).symbolize_keys
      end

      def exists?(style = default_style)
        if original_filename
          s3_object(style).exists?
        else
          false
        end
      rescue AWS::Errors::Base => e
        false
      end

      def s3_permissions(style = default_style)
        s3_permissions = @s3_permissions[style] || @s3_permissions[:default]
        s3_permissions = s3_permissions.call(self, style) if s3_permissions.respond_to?(:call)
        s3_permissions
      end

      def s3_protocol(style = default_style, with_colon = false)
        protocol = @s3_protocol
        protocol = protocol.call(style, self) if protocol.respond_to?(:call)

        if with_colon && !protocol.empty?
          "#{protocol}:"
        else
          protocol.to_s
        end
      end

      def create_bucket
        s3_interface.buckets.create(bucket_name)
      end

      def flush_writes #:nodoc:
        @queued_for_write.each do |style, file|
          begin
            log("saving #{path(style)}")
            acl = @s3_permissions[style] || @s3_permissions[:default]
            acl = acl.call(self, style) if acl.respond_to?(:call)
            write_options = {
              :content_type => file.content_type,
              :acl => acl
            }
            if @s3_server_side_encryption
              write_options[:server_side_encryption] = @s3_server_side_encryption
            end

            style_specific_options = @options[:styles][style]
            if style_specific_options.is_a?(Hash)
              merge_s3_headers( style_specific_options[:s3_headers], @s3_headers, @s3_metadata) if style_specific_options.has_key?(:s3_headers)
              @s3_metadata.merge!(style_specific_options[:s3_metadata]) if style_specific_options.has_key?(:s3_metadata)
            end

            write_options[:metadata] = @s3_metadata unless @s3_metadata.empty?
            write_options.merge!(@s3_headers)

            s3_object(style).write(file, write_options)
          rescue AWS::S3::Errors::NoSuchBucket => e
            create_bucket
            retry
          ensure
            file.rewind
          end
        end

        after_flush_writes # allows attachment to clean up temp files

        @queued_for_write = {}
      end

      def flush_deletes #:nodoc:
        @queued_for_delete.each do |path|
          begin
            log("deleting #{path}")
            s3_bucket.objects[path.sub(%r{^/},'')].delete
          rescue AWS::Errors::Base => e
            # Ignore this.
          end
        end
        @queued_for_delete = []
      end

      def copy_to_local_file(style, local_dest_path)
        log("copying #{path(style)} to local file #{local_dest_path}")
        local_file = ::File.open(local_dest_path, 'wb')
        file = s3_object(style)
        local_file.write(file.read)
        local_file.close
      rescue AWS::Errors::Base => e
        warn("#{e} - cannot copy #{path(style)} to local file #{local_dest_path}")
        false
      end

      private

      def find_credentials creds
        case creds
        when File
          YAML::load(ERB.new(File.read(creds.path)).result)
        when String, Pathname
          YAML::load(ERB.new(File.read(creds)).result)
        when Hash
          creds
        else
          raise ArgumentError, "Credentials are not a path, file, proc, or hash."
        end
      end

      def use_secure_protocol?(style_name)
        s3_protocol(style_name) == "https"
      end

      def merge_s3_headers(http_headers, s3_headers, s3_metadata)
        return if http_headers.nil?
        http_headers = http_headers.call(instance) if http_headers.respond_to?(:call)
        http_headers.inject({}) do |headers,(name,value)|
          case name.to_s
          when /^x-amz-meta-(.*)/i
            s3_metadata[$1.downcase] = value
          else
            s3_headers[name.to_s.downcase.sub(/^x-amz-/,'').tr("-","_").to_sym] = value
          end
        end
      end
    end
  end
end
