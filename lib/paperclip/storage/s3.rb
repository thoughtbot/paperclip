module Thoughtbot
  module Paperclip
    module ClassMethods #:nodoc:
      def has_attached_file_with_s3 *attachment_names
        attachments, options = has_attached_file_without_s3 *attachment_names

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

        if options[:storage].to_s.downcase == "s3"
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

    class Storage #:nodoc:
      class S3 < Storage #:nodoc:
        def path_for attachment, style = nil
          style ||= attachment[:default_style]
          file = attachment[:instance]["#{attachment[:name]}_file_name"]
          return nil unless file && attachment[:instance].id

          interpolate attachment, attachment[:path], style
        end
        
        def url_for attachment, style = nil
          "http://s3.amazonaws.com/#{bucket_for(attachment)}/#{path_for(attachment, style)}"
        end

        def bucket_for attachment
          bucket_name = interpolate attachment, attachment[:url_prefix], nil
        end

        def ensure_bucket_for attachment, style = nil
          begin
            bucket_name = bucket_for attachment
            AWS::S3::Bucket.create(bucket_name)
            bucket_name
          rescue AWS::S3::S3Exception => e
            raise Thoughtbot::Paperclip::PaperclipError.new(attachment), "You are not allowed access to the bucket '#{bucket_name}'."
          end
        end

        def write_attachment attachment
          return if attachment[:files].blank?
          bucket = ensure_bucket_for attachment
          attachment[:files].each do |style, atch|
            atch.rewind
            AWS::S3::S3Object.store( path_for(attachment, style), atch, bucket, :access => attachment[:access] || :public_read )
          end
          attachment[:files] = nil
          attachment[:dirty] = false
        end

        def delete_attachment attachment, complain = false
          (attachment[:thumbnails].keys + [:original]).each do |style|
            file_path = path_for(attachment, style)
            AWS::S3::S3Object.delete( file_path, bucket_for(attachment) )
          end
        end

        def attachment_valid? attachment
          attachment[:thumbnails].merge(:original => nil).all? do |style, geometry|
            if attachment[:instance]["#{attachment[:name]}_file_name"]
              if attachment[:dirty]
                !attachment[:files][style].blank? && attachment[:errors].empty?
              else
                AWS::S3::S3Object.exists?( path_for(attachment, style), bucket_for(attachment) )
              end
            else
              false
            end
          end
        end
      end
    end
  end
end