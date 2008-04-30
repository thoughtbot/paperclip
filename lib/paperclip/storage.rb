module Paperclip
  module Storage

    module Filesystem
      def self.extended base
      end
      
      def exists?(style = default_style)
        if original_filename
          File.exist?(path(style))
        else
          false
        end
      end

      # Returns representation of the data of the file assigned to the given
      # style, in the format most representative of the current storage.
      def to_file style = default_style
        @queued_for_write[style] || (File.new(path(style)) if exists?(style))
      end
      alias_method :to_io, :to_file

      def flush_writes #:nodoc:
        @queued_for_write.each do |style, file|
          FileUtils.mkdir_p(File.dirname(path(style)))
          result = file.stream_to(path(style))
          file.close
          result.close
        end
        @queued_for_write = {}
      end

      def flush_deletes #:nodoc:
        @queued_for_delete.each do |path|
          begin
            FileUtils.rm(path) if File.exist?(path)
          rescue Errno::ENOENT => e
            # ignore file-not-found, let everything else pass
          end
        end
        @queued_for_delete = []
      end
    end

    module S3
      def self.extended base
        require 'right_aws'
        base.instance_eval do
          @bucket             = @options[:bucket]
          @s3_credentials     = parse_credentials(@options[:s3_credentials])
          @s3_options         = @options[:s3_options] || {}
          @s3_permissions     = @options[:s3_permissions] || 'public-read'
          @url                = ":s3_url"
        end
        base.class.interpolations[:s3_url] = lambda do |attachment, style|
          "https://s3.amazonaws.com/#{attachment.bucket_name}/#{attachment.path(style).gsub(%r{^/}, "")}"
        end
      end

      def s3
        @s3 ||= RightAws::S3.new(@s3_credentials[:access_key_id],
                                 @s3_credentials[:secret_access_key],
                                 @s3_options)
      end

      def s3_bucket
        @s3_bucket ||= s3.bucket(@bucket, true, @s3_permissions)
      end

      def bucket_name
        @bucket
      end

      def parse_credentials creds
        creds = find_credentials(creds).stringify_keys
        (creds[ENV['RAILS_ENV']] || creds).symbolize_keys
      end
      
      def exists?(style = default_style)
        s3_bucket.key(path(style)) ? true : false
      end

      # Returns representation of the data of the file assigned to the given
      # style, in the format most representative of the current storage.
      def to_file style = default_style
        @queued_for_write[style] || s3_bucket.key(path(style))
      end
      alias_method :to_io, :to_file

      def flush_writes #:nodoc:
        @queued_for_write.each do |style, file|
          begin
            key = s3_bucket.key(path(style))
            key.data = file
            key.put(nil, @s3_permissions)
          rescue RightAws::AwsError => e
            raise
          end
        end
        @queued_for_write = {}
      end

      def flush_deletes #:nodoc:
        @queued_for_delete.each do |path|
          begin
            if file = s3_bucket.key(path)
              file.delete
            end
          rescue RightAws::AwsError
            # Ignore this.
          end
        end
        @queued_for_delete = []
      end
      
      def find_credentials creds
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
      private :find_credentials

    end
  end
end
