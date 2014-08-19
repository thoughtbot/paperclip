module Paperclip
  module Storage
    # fog is a modern and versatile cloud computing library for Ruby.
    # Among others, it supports Amazon S3 to store your files. In
    # contrast to the outdated AWS-S3 gem it is actively maintained and
    # supports multiple locations.
    # Amazon's S3 file hosting service is a scalable, easy place to
    # store files for distribution. You can find out more about it at
    # http://aws.amazon.com/s3 There are a few fog-specific options for
    # has_attached_file, which will be explained using S3 as an example:
    # * +fog_credentials+: Takes a Hash with your credentials. For S3,
    #   you can use the following format:
    #     aws_access_key_id: '<your aws_access_key_id>'
    #     aws_secret_access_key: '<your aws_secret_access_key>'
    #     provider: 'AWS'
    #     region: 'eu-west-1'
    #     scheme: 'https'
    # * +fog_directory+: This is the name of the S3 bucket that will
    #   store your files.  Remember that the bucket must be unique across
    #   all of Amazon S3. If the bucket does not exist, Paperclip will
    #   attempt to create it.
    # * +fog_file*: This can be hash or lambda returning hash. The
    #   value is used as base properties for new uploaded file.
    # * +path+: This is the key under the bucket in which the file will
    #   be stored. The URL will be constructed from the bucket and the
    #   path. This is what you will want to interpolate. Keys should be
    #   unique, like filenames, and despite the fact that S3 (strictly
    #   speaking) does not support directories, you can still use a / to
    #   separate parts of your file name.
    # * +fog_public+: (optional, defaults to true) Should the uploaded
    #   files be public or not? (true/false)
    # * +fog_host+: (optional) The fully-qualified domain name (FQDN)
    #   that is the alias to the S3 domain of your bucket, e.g.
    #   'http://images.example.com'. This can also be used in
    #   conjunction with Cloudfront (http://aws.amazon.com/cloudfront)

    module Fog
      def self.extended base
        begin
          require 'fog'
        rescue LoadError => e
          e.message << " (You may need to install the fog gem)"
          raise e
        end unless defined?(Fog)

        base.instance_eval do
          unless @options[:url].to_s.match(/\A:fog.*url\Z/)
            @options[:path]  = @options[:path].gsub(/:url/, @options[:url]).gsub(/\A:rails_root\/public\/system\//, '')
            @options[:url]   = ':fog_public_url'
          end
          Paperclip.interpolates(:fog_public_url) do |attachment, style|
            attachment.public_url(style)
          end unless Paperclip::Interpolations.respond_to? :fog_public_url
        end
      end

      AWS_BUCKET_SUBDOMAIN_RESTRICTON_REGEX = /\A(?:[a-z]|\d(?!\d{0,2}(?:\.\d{1,3}){3}\Z))(?:[a-z0-9]|\.(?![\.\-])|\-(?![\.])){1,61}[a-z0-9]\Z/

      def exists?(style = default_style)
        if original_filename
          !!directory.files.head(path(style))
        else
          false
        end
      end

      def fog_credentials
        @fog_credentials ||= parse_credentials(@options[:fog_credentials])
      end

      def fog_file
        @fog_file ||= begin
          value = @options[:fog_file]
          if !value
            {}
          elsif value.respond_to?(:call)
            value.call(self)
          else
            value
          end
        end
      end

      def fog_public(style = default_style)
        if @options.has_key?(:fog_public)
          if @options[:fog_public].respond_to?(:has_key?) && @options[:fog_public].has_key?(style)
            @options[:fog_public][style]
          else
            @options[:fog_public]
          end
        else
          true
        end
      end

      def flush_writes
        for style, file in @queued_for_write do
          log("saving #{path(style)}")
          retried = false
          begin
            directory.files.create(fog_file.merge(
              :body         => file,
              :key          => path(style),
              :public       => fog_public(style),
              :content_type => file.content_type
            ))
          rescue Excon::Errors::NotFound
            raise if retried
            retried = true
            directory.save
            retry
          ensure
            file.rewind
          end
        end

        after_flush_writes # allows attachment to clean up temp files

        @queued_for_write = {}
      end

      def flush_deletes
        for path in @queued_for_delete do
          log("deleting #{path}")
          directory.files.new(:key => path).destroy
        end
        @queued_for_delete = []
      end

      def public_url(style = default_style)
        if @options[:fog_host]
          "#{dynamic_fog_host_for_style(style)}/#{path(style)}"
        else
          if fog_credentials[:provider] == 'AWS'
            "#{scheme}://#{host_name_for_directory}/#{path(style)}"
          else
            directory.files.new(:key => path(style)).public_url
          end
        end
      end

      def expiring_url(time = (Time.now + 3600), style_name = default_style)
        time = convert_time(time)
        if path(style_name) && directory.files.respond_to?(:get_http_url)
          expiring_url = directory.files.get_http_url(path(style_name), time)

          if @options[:fog_host]
            expiring_url.gsub!(/#{host_name_for_directory}/, dynamic_fog_host_for_style(style_name))
          end
        else
          expiring_url = url(style_name)
        end

        return expiring_url
      end

      def parse_credentials(creds)
        creds = find_credentials(creds).stringify_keys
        env = Object.const_defined?(:Rails) ? Rails.env : nil
        (creds[env] || creds).symbolize_keys
      end

      def copy_to_local_file(style, local_dest_path)
        log("copying #{path(style)} to local file #{local_dest_path}")
        ::File.open(local_dest_path, 'wb') do |local_file|
          file = directory.files.get(path(style))
          local_file.write(file.body)
        end
      rescue ::Fog::Errors::Error => e
        warn("#{e} - cannot copy #{path(style)} to local file #{local_dest_path}")
        false
      end

      private

      def convert_time(time)
        if time.is_a?(Fixnum)
          time = Time.now + time
        end
        time
      end

      def dynamic_fog_host_for_style(style)
        if @options[:fog_host].respond_to?(:call)
          @options[:fog_host].call(self)
        else
          (@options[:fog_host] =~ /%d/) ? @options[:fog_host] % (path(style).hash % 4) : @options[:fog_host]
        end
      end

      def host_name_for_directory
        if @options[:fog_directory].to_s =~ Fog::AWS_BUCKET_SUBDOMAIN_RESTRICTON_REGEX
          "#{@options[:fog_directory]}.s3.amazonaws.com"
        else
          "s3.amazonaws.com/#{@options[:fog_directory]}"
        end
      end

      def find_credentials(creds)
        case creds
        when File
          YAML::load(ERB.new(File.read(creds.path)).result)
        when String, Pathname
          YAML::load(ERB.new(File.read(creds)).result)
        when Hash
          creds
        else
          if creds.respond_to?(:call)
            creds.call(self)
          else
            raise ArgumentError, "Credentials are not a path, file, hash or proc."
          end
        end
      end

      def connection
        @connection ||= ::Fog::Storage.new(fog_credentials)
      end

      def directory
        dir = if @options[:fog_directory].respond_to?(:call)
          @options[:fog_directory].call(self)
        else
          @options[:fog_directory]
        end

        @directory ||= connection.directories.new(:key => dir)
      end

      def scheme
        @scheme ||= fog_credentials[:scheme] || 'https'
      end
    end
  end
end
