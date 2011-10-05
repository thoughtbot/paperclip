module Paperclip
  class Options

    attr_accessor :url, :path, :only_process, :normalized_styles, :default_url, :default_style,
     :storage, :use_timestamp, :whiny, :use_default_time_zone, :hash_digest, :hash_secret,
     :convert_options, :source_file_options, :preserve_files, :http_proxy

    attr_accessor :s3_credentials, :s3_host_name, :s3_options, :s3_permissions, :s3_protocol,
      :s3_headers, :s3_host_alias, :bucket

    attr_accessor :fog_directory, :fog_credentials, :fog_host, :fog_public, :fog_file

    def initialize(attachment, hash)
      @attachment            = attachment

      @url                   = hash[:url]
      @url                   = @url.call(@attachment) if @url.is_a?(Proc)
      @path                  = hash[:path]
      @path                  = @path.call(@attachment) if @path.is_a?(Proc)
      @styles                = hash[:styles]
      @only_process          = hash[:only_process]
      @normalized_styles     = nil
      @default_url           = hash[:default_url]
      @default_style         = hash[:default_style]
      @storage               = hash[:storage]
      @use_timestamp         = hash[:use_timestamp]
      @whiny                 = hash[:whiny_thumbnails] || hash[:whiny]
      @use_default_time_zone = hash[:use_default_time_zone]
      @hash_digest           = hash[:hash_digest]
      @hash_data             = hash[:hash_data]
      @hash_secret           = hash[:hash_secret]
      @convert_options       = hash[:convert_options]
      @source_file_options   = hash[:source_file_options]
      @processors            = hash[:processors]
      @preserve_files        = hash[:preserve_files]
      @http_proxy            = hash[:http_proxy]

      #s3 options
      @s3_credentials        = hash[:s3_credentials]
      @s3_host_name          = hash[:s3_host_name]
      @bucket                = hash[:bucket]
      @s3_options            = hash[:s3_options]
      @s3_permissions        = hash[:s3_permissions]
      @s3_protocol           = hash[:s3_protocol]
      @s3_headers            = hash[:s3_headers]
      @s3_host_alias         = hash[:s3_host_alias]

      #fog options
      @fog_directory         = hash[:fog_directory]
      @fog_credentials       = hash[:fog_credentials]
      @fog_host              = hash[:fog_host]
      @fog_public            = hash[:fog_public]
      @fog_file              = hash[:fog_file]
    end

    def method_missing(method, *args, &blk)
      if method.to_s[-1,1] == "="
        instance_variable_set("@#{method[0..-2]}", args[0])
      else
        instance_variable_get("@#{method}")
      end
    end

    def processors
      @processors.respond_to?(:call) ? @processors.call(@attachment.instance) : @processors
    end

    def styles
      if @styles.respond_to?(:call) || !@normalized_styles
        @normalized_styles = ActiveSupport::OrderedHash.new
        (@styles.respond_to?(:call) ? @styles.call(@attachment) : @styles).each do |name, args|
          normalized_styles[name] = Paperclip::Style.new(name, args.dup, @attachment)
        end
      end
      @normalized_styles
    end
  end
end
