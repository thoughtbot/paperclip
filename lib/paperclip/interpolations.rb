module Paperclip
  module Interpolations
    extend self

    def self.[]= name, block
      define_method(name, &block)
    end

    def self.[] name
      method(name)
    end

    def self.all
      self.instance_methods(false).sort
    end

    def self.interpolate pattern, *args
      all.reverse.inject( pattern.dup ) do |result, tag|
        result.gsub(/:#{tag}/) do |match|
          send( tag, *args )
        end
      end
    end

    def filename attachment, style
      "#{basename(attachment, style)}.#{extension(attachment, style)}"
    end

    def url attachment, style
      raise InfiniteInterpolationError if attachment.options[:url].include?(":url")
      attachment.url(style)
    end

    def timestamp attachment, style
      attachment.instance_read(:updated_at).to_s
    end

    def rails_root attachment, style
      RAILS_ROOT
    end

    def rails_env attachment, style
      RAILS_ENV
    end

    def class attachment, style
      attachment.instance.class.to_s.underscore.pluralize
    end

    def basename attachment, style
      attachment.original_filename.gsub(/#{File.extname(attachment.original_filename)}$/, "")
    end

    def extension attachment, style 
      ((style = attachment.styles[style]) && style[:format]) ||
        File.extname(attachment.original_filename).gsub(/^\.+/, "")
    end

    def id attachment, style
      attachment.instance.id
    end

    def id_partition attachment, style
      ("%09d" % attachment.instance.id).scan(/\d{3}/).join("/")
    end

    def attachment attachment, style
      attachment.name.to_s.downcase.pluralize
    end

    def style attachment, style
      style || attachment.default_style
    end
  end
end
