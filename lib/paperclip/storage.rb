module Paperclip
  module Storage

    # With the Filesystem module installed, @file and @processed_files are just File instances.
    module Filesystem
      def self.extended base
      end

      def locate_files
        [:original, *@styles.keys].uniq.inject({}) do |files, style|
          files[style] = File.new(path(style), "rb") if File.exist?(path(style))
          files
        end
      end

      def flush_writes #:nodoc:
        @processed_files.each do |style, file|
          FileUtils.mkdir_p( File.dirname(path(style)) )
          @processed_files[style] = file.stream_to(path(style)) unless file.path == path(style)
        end
      end

      def flush_deletes #:nodoc:
        @queued_for_delete.compact.each do |file|
          begin
            FileUtils.rm(file.path)
          rescue Errno::ENOENT => e
            # ignore them
          end
        end
        @queued_for_delete = []
      end
    end

    # With the S3 module included, @file and the @processed_files will be
    # RightAws::S3::Key instances.
    module S3
      def self.extended base
        require 'right_aws'
        base.instance_eval do
          @bucket             = @options[:bucket]
          @s3_credentials     = parse_credentials(@options[:s3_credentials])
          @s3_options         = @options[:s3_options] || {}
          @s3_permissions     = @options[:s3_permissions] || 'public-read'

          @s3                 = RightAws::S3.new(@s3_credentials['access_key_id'],
                                                 @s3_credentials['secret_access_key'],
                                                 @s3_options)
          @s3_bucket          = @s3.bucket(@bucket, true, @s3_permissions)
          @url                = ":s3_url"
        end
        base.class.interpolations[:s3_url] = lambda do |attachment, style|
          attachment.to_io(style).public_link
        end
      end

      def parse_credentials creds
        case creds
        when File:
          YAML.load_file(creds.path)
        when String:
          YAML.load_file(creds)
        when Hash:
          creds
        else
          raise ArgumentError, "Credentials are not a path, file, or hash."
        end
      end

      def locate_files
        [:original, *@styles.keys].uniq.inject({}) do |files, style|
          files[style] = @s3_bucket.key(path(style))
          files
        end
      end

      def flush_writes #:nodoc:
        return if not dirty?
        @processed_files.each do |style, key|
          begin
            unless key.is_a? RightAws::S3::Key
              saved_data = key
              key = @processed_files[style] = @s3_bucket.key(path(style))
              key.data = saved_data
            end
            key.put(nil, @s3_permissions)
          rescue RightAws::AwsError => e
            @processed_files[style] = nil
            raise
          end
        end
      end

      def flush_deletes #:nodoc:
        @queued_for_delete.compact.each do |file|
          begin
            file.delete
          rescue RightAws::AwsError
            # Ignore this.
          end
        end
        @queued_for_delete = []
      end

    end
  end
end
