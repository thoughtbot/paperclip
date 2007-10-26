module Thoughtbot
  module Paperclip
    class AttachmentDefinition
      
      def self.defaults
        {
          :path_prefix        => ":rails_root/public",
          :url_prefix         => "",
          :path               => ":attachment/:id/:style_:name",
          :url                => nil,
          :attachment_type    => :image,
          :thumbnails         => {},
          :delete_on_destroy  => true,
          :default_style      => :original,
          :missing_url        => "",
          :missing_path       => "",
          :storage            => :filesystem
        }
      end
      
      def initialize name, options
        @name = name
        @options = AttachmentDefinition.defaults.merge options
      end
      
      def name
        @name
      end
      
      def styles
        unless @styles
          @styles = @options[:thumbnails]
          @styles[:original] = nil
        end
        @styles
      end
      
      def validate thing, *constraints
        @options[:"validate_#{thing}"] = (constraints.length == 1 ? constraints.first : constraints)
      end
      
      def validations
        @validations ||= @options.inject({}) do |valids, opts|
          key, val = opts
          if (m = key.to_s.match(/^validate_(.+)/))
            valids[m[1]] = val
          end
          valids
        end
      end
      
      def storage_module
        @storage_module ||= Thoughtbot::Paperclip::Storage.const_get(@options[:storage].to_s.camelize)
      end
      
      def type
        @options[:attachment_type]
      end
      
      def default_style
        @options[:default_style]
      end
      
      def path_prefix
        @options[:path_prefix]
      end
      
      def url_prefix
        @options[:url_prefix]
      end
      
      def path
        @options[:path]
      end
      
      def url
        @options[:url]
      end
      
      def missing_file_name
        @options[:missing_path]
      end
      
      def missing_url
        @options[:missing_url]
      end
      
      def delete_on_destroy
        @options[:delete_on_destroy]
      end
    end
  end
end