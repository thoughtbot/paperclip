module Thoughtbot
  module Paperclip
    
    module ClassMethods
      def has_attached_file_with_s3 *attachment_names
        has_attached_file_without_s3 *attachment_names

        access_key = secret_key = ""
        if file_name = s3_credentials_file
          creds = YAML.load_file(file_name)
          creds = creds[RAILS_ENV] || creds if Object.const_defined?("RAILS_ENV")
          access_key = creds['access_key_id']
          secret_key = creds['secret_access_key']
        else
          access_key = Thoughtbot::Paperclip.options[:s3_access_key_id]
          secret_key = Thoughtbot::Paperclip.options[:s3_secret_access_key]
        end

        if definition.storage_module == Thoughtbot::Paperclip::Storage::S3
          require 'aws/s3'
          AWS::S3::Base.establish_connection!(
            :access_key_id     => access_key,
            :secret_access_key => secret_key,
            :persistent        => Thoughtbot::Paperclip.options[:s3_persistent] || true
          )
        end
      end
      alias_method_chain :has_attached_file, :s3
      
      private
      def s3_credentials_file
        [ Thoughtbot::Paperclip.options[:s3_credentials_file], File.join(RAILS_ROOT, "config", "s3.yml") ].compact.each do |f|
          return f if File.exists?(f)
        end
        nil
      end
    end
    
    class AttachmentDefinition
      def s3_access
        @options[:s3_access_privilege]
      end
    end
    
    module Storage
      # == Amazon S3 Storage
      # Paperclip can store your files in Amazon's S3 Web Service. You can keep your keys in an s3.yml
      # file inside the +config+ directory, similarly to your database.yml.
      #
      #   access_key_id: 12345
      #   secret_access_key: 212434...4656456
      #
      # You can also environment-namespace the entries like you would in your database.yml:
      #
      #   development:
      #     access_key_id: 12345
      #     secret_access_key: 212434...4656456
      #   production:
      #     access_key_id: abcde
      #     secret_access_key: gbkjhg...wgbrtjh
      #
      # The location of this file is configurable. You don't even have to use it if you don't want. Both
      # the file's location or the keys themselves may be located in the Thoughtbot::Paperclip.options
      # hash. The S3-related options in this hash are all prefixed with "s3".
      #
      #   Thoughtbot::Paperclip.options = {
      #     :s3_persistent => true,
      #     :s3_credentials_file => "/home/me/.private/s3.yml"
      #   }
      #
      # This configuration is best placed in your +environment.rb+ or env-specific file.
      # The complete list of options is as follows:
      # * s3_access_key_id: The Amazon S3 ID you were given to access your account.
      # * s3_secret_access_key: The secret key supplied by Amazon. This should be kept far away from prying
      #   eyes, which is why it's suggested that you keep these keys in a separate file that
      #   only you and the database can read.
      # * s3_credentials_file: The path to the file where your credentials are kept in YAML format, as
      #   described above.
      # * s3_persistent: Maintains an HTTP connection to the Amazon service if possible.
      module S3
        def file_name style = nil
          style ||= definition.default_style
          pattern = if original_filename && instance.id
            definition.url
          else
            definition.missing_url
          end
          interpolate( style, pattern )
        end

        def url style = nil
          "http://s3.amazonaws.com/#{bucket}/#{file_name(style)}"
        end

        def write_attachment
          bucket = ensure_bucket
          for_attached_files do |style, data|
            AWS::S3::S3Object.store( file_name(style), data, bucket, :access => definition.s3_access || :public_read )
          end
        end

        def delete_attachment complain = false
          for_attached_files do |style, data|
            begin
              AWS::S3::S3Object.delete( file_name(style), bucket )
            rescue AWS::S3::ResponseError => error
              raise
            end
          end
        end
        
        def file_exists?(style)
          style ||= definition.default_style
          dirty? ? file_for(style) : AWS::S3::S3Object.exists?( file_name(style), bucket )
        end
        
        def validate_existence *constraints
          definition.styles.keys.each do |style|
            errors << "requires a valid #{style} file." unless file_exists?(style)
          end
        end
        
        def validate_size *constraints
          errors << "file too large. Must be under #{constraints.last} bytes." if original_file_size > constraints.last
          errors << "file too small. Must be over #{constraints.first} bytes." if original_file_size <= constraints.first
        end
        
        private
        
        def bucket
          interpolate(nil, definition.url_prefix)
        end

        def ensure_bucket
          begin
            bucket_name = bucket
            AWS::S3::Bucket.create(bucket_name)
            bucket_name
          rescue AWS::S3::S3Exception => e
            raise Thoughtbot::Paperclip::PaperclipError.new(attachment), "You are not allowed access to the bucket '#{bucket_name}'."
          end
        end

      end
    end
  end
end