module Paperclip  
  module Storage
    module S3
      def self.extended(base)
        Paperclip.options[:s3] ||= {}
        Paperclip::Attachment.interpolations[:bucket] = lambda{|style, atch| atch.definition.bucket }
        
        access_key, secret_key = credentials
        require 'aws/s3'
        AWS::S3::Base.establish_connection!(
          :access_key_id     => access_key,
          :secret_access_key => secret_key,
          :persistent        => Paperclip.options[:s3][:persistent] || true
        )
      end
      
      def self.credentials
        if credentials_file
          creds = YAML.load_file(credentials_file)
          creds = creds[RAILS_ENV] || creds if Object.const_defined?("RAILS_ENV")
          [ creds['access_key_id'], creds['secret_access_key'] ]
        else
          [ Paperclip.options[:s3][:access_key_id], Paperclip.options[:s3][:secret_access_key] ]
        end
      end
      
      def self.credentials_file
        @file ||= [ Paperclip.options[:s3][:credentials_file], File.join(RAILS_ROOT, "config", "s3.yml") ].compact.find do |f|
          File.exists?(f)
        end
      end
      
      def url_with_s3 style = nil
        http_host = definition.s3_host || "http://s3.amazonaws.com"
        "#{http_host}/#{bucket}/#{url_without_s3(style)}"
      end
      
      def file_name style = nil
        style ||= definition.default_style
        interpolate( style, definition.url )
      end
      
      def attachment_exists? style = nil
        AWS::S3::S3Object.exists?( file_name(style), bucket )
      end

      def bucket
        definition.bucket
      end

      def ensure_bucket
        begin
          AWS::S3::Bucket.create(bucket)
          bucket
        rescue AWS::S3::S3Exception => e
          raise Paperclip::PaperclipError, "You are not allowed access to the bucket '#{bucket_name}'."
        end
      end
      
      def write_attachment
        ensure_bucket
        for_attached_files do |style, data|
          AWS::S3::S3Object.store( file_name(style), data, bucket, :access => definition.s3_access || :public_read )
        end
      end
      
      def read_attachment style = nil
        AWS::S3::S3Object.value( file_name(style), bucket )
      end
      
      def stream style = nil, &block
        AWS::S3::S3Object.stream( file_name(style), bucket, &block )
      end

      def delete_attachment complain = false
        for_attached_files do |style|
          AWS::S3::S3Object.delete( file_name(style), bucket )
        end
      end

    end
  end
end