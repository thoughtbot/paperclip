module Paperclip
  module Interpolations
    def self.[]= name, block
      (class << self; self; end).class_eval do
        define_method(name, &block)
      end
    end

    def self.[] name
      method(name)
    end

    def self.all
      (singleton_methods - ["[]=", "[]", "all"]).sort
    end

    def self.rails_root attachment, style
      RAILS_ROOT
    end

    def self.rails_env attachment, style
      RAILS_ENV
    end

    def self.class attachment, style
      attachment.instance.class.to_s.underscore.pluralize
    end

    def self.basename attachment, style
      attachment.original_filename.gsub(/#{File.extname(attachment.original_filename)}$/, "")
    end

    def self.extension attachment, style 
      ((style = attachment.styles[style]) && style[:format]) ||
        File.extname(attachment.original_filename).gsub(/^\.+/, "")
    end

    def self.id attachment, style
      attachment.instance.id
    end

    def self.id_partition attachment, style
      ("%09d" % attachment.instance.id).scan(/\d{3}/).join("/")
    end

    def self.attachment attachment, style
      attachment.name.to_s.downcase.pluralize
    end

    def self.style attachment, style
      style || attachment.default_style
    end
  end
end
