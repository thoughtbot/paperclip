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
    #
    #   You can set permission on a per style bases by doing the following:
    #     :fog_permissions => {
    #       :original => :private
    #     }
    #   Or globaly:
    #     :fog_permissions => :private
    #
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
          @fog_directory    = @options[:fog_directory]
          @fog_credentials  = @options[:fog_credentials]
          @fog_host         = @options[:fog_host]
          @fog_permissions  = set_permissions(@options[:fog_permissions])
          @fog_public       = @options[:fog_public]

          @url = ':fog_public_url'
          Paperclip.interpolates(:fog_public_url) do |attachment, style|
            attachment.public_url(style)
          end unless Paperclip::Interpolations.respond_to? :fog_public_url
        end
      end

      def set_permissions permissions
        if permissions.is_a?(Hash)
          permissions[:default] = permissions[:default] || :public_read
        else
          permissions = { :default => permissions || :public_read }
        end
        permissions
      end

      def exists?(style = default_style)
        if original_filename
          !!directory.files.head(path(style))
        else
          false
        end
      end

      def flush_writes
        for style, file in @queued_for_write do
          log("saving #{path(style)}")
          directory.files.create(
            :body   => file,
            :key    => path(style),
            :public => (@fog_permissions[style] || @fog_permissions[:default])
          )
        end
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
        if @fog_host
          host = (@fog_host =~ /%d/) ? @fog_host % (path(style).hash % 4) : @fog_host
          "#{host}/#{path(style)}"
        else
          directory.files.new(:key => path(style)).public_url
        end
      end

      private

      def connection
        @connection ||= ::Fog::Storage.new(@fog_credentials)
      end

      def directory
        @directory ||= begin
          connection.directories.get(@fog_directory) || connection.directories.create(
            :key => @fog_directory,
            :public => @fog_public
          )
        end
      end

    end

  end
end
