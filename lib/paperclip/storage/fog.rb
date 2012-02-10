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
    # * +fog_directory+: This is the name of the S3 bucket that will
    #   store your files.  Remember that the bucket must be unique across
    #   all of Amazon S3. If the bucket does not exist, Paperclip will
    #   attempt to create it.
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
          unless @options[:url].to_s.match(/^:fog.*url$/)
            @options[:path]  = @options[:path].gsub(/:url/, @options[:url])
            @options[:url]   = ':fog_public_url'
          end
          Paperclip.interpolates(:fog_public_url) do |attachment, style|
            attachment.public_url(style)
          end unless Paperclip::Interpolations.respond_to? :fog_public_url
        end
      end

      AWS_BUCKET_SUBDOMAIN_RESTRICTON_REGEX = /^(?:[a-z]|\d(?!\d{0,2}(?:\.\d{1,3}){3}$))(?:[a-z0-9]|\.(?![\.\-])|\-(?![\.])){1,61}[a-z0-9]$/

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
        @fog_file ||= @options[:fog_file] || {}
      end

      def fog_public
        return @fog_public if defined?(@fog_public)
        @fog_public = defined?(@options[:fog_public]) ? @options[:fog_public] : true
      end

      def flush_writes
        for style, file in @queued_for_write do
          log("saving #{path(style)}")
          retried = false
          begin
            directory.files.create(fog_file.merge(
              :body         => file,
              :key          => path(style),
              :public       => fog_public,
              :content_type => file.content_type.to_s.strip
            ))
          rescue Excon::Errors::NotFound
            raise if retried
            retried = true
            directory.save
            retry
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

      # Returns representation of the data of the file assigned to the given
      # style, in the format most representative of the current storage.
      def to_file(style = default_style)
        if @queued_for_write[style]
          @queued_for_write[style].rewind
          @queued_for_write[style]
        else
          body      = directory.files.get(path(style)).body
          filename  = path(style)
          extname   = File.extname(filename)
          basename  = File.basename(filename, extname)
          file      = Tempfile.new([basename, extname])
          file.binmode
          file.write(body)
          file.rewind
          file
        end
      end

      def public_url(style = default_style)
        if @options[:fog_host]
          host = if @options[:fog_host].respond_to?(:call)
            @options[:fog_host].call(self)
          else
            (@options[:fog_host] =~ /%d/) ? @options[:fog_host] % (path(style).hash % 4) : @options[:fog_host]
          end
          
          "#{host}/#{path(style)}"
        else
          if fog_credentials[:provider] == 'AWS'
            if @options[:fog_directory].to_s =~ Fog::AWS_BUCKET_SUBDOMAIN_RESTRICTON_REGEX
              "https://#{@options[:fog_directory]}.s3.amazonaws.com/#{path(style)}"
            else
              # directory is not a valid subdomain, so use path style for access
              "https://s3.amazonaws.com/#{@options[:fog_directory]}/#{path(style)}"
            end
          else
            directory.files.new(:key => path(style)).public_url
          end
        end
      end

      def parse_credentials(creds)
        creds = find_credentials(creds).stringify_keys
        env = Object.const_defined?(:Rails) ? Rails.env : nil
        (creds[env] || creds).symbolize_keys
      end

      private

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
    end
  end
end
