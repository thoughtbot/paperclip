module Paperclip
  # This module contains all the methods that are available for interpolation
  # in paths and urls. To add your own (or override an existing one), you
  # can either open this module and define it, or call the
  # Paperclip.interpolates method.
  module Interpolations
    extend self

    # Hash assignment of interpolations. Included only for compatability,
    # and is not intended for normal use.
    def self.[]= name, block
      define_method(name, &block)
    end

    # Hash access of interpolations. Included only for compatability,
    # and is not intended for normal use.
    def self.[] name
      method(name)
    end

    # Returns a sorted list of all interpolations.
    def self.all
      self.instance_methods(false).sort
    end

    # Perform the actual interpolation. Takes the pattern to interpolate
    # and the arguments to pass, which are the attachment and style name.
    def self.interpolate pattern, *args
      all.reverse.inject( pattern.dup ) do |result, tag|
        result.gsub(/:#{tag}/) do |match|
          send( tag, *args )
        end
      end
    end

    # Returns the filename, the same way as ":basename.:extension" would.
    def filename attachment, style_name
      "#{basename(attachment, style_name)}.#{extension(attachment, style_name)}"
    end

    # Returns the interpolated URL. Will raise an error if the url itself
    # contains ":url" to prevent infinite recursion. This interpolation
    # is used in the default :path to ease default specifications.
    def url attachment, style_name
      raise InfiniteInterpolationError if caller.any?{|b| b.index("#{__FILE__}:#{__LINE__ + 1}") }
      attachment.url(style_name, false)
    end

    # Returns the timestamp as defined by the <attachment>_updated_at field
    def timestamp attachment, style_name
      attachment.instance_read(:updated_at).to_s
    end

    # Returns the Rails.root constant.
    def rails_root attachment, style_name
      Rails.root
    end

    # Returns the Rails.env constant.
    def rails_env attachment, style_name
      Rails.env
    end

    # Returns the underscored, pluralized version of the class name.
    # e.g. "users" for the User class.
    # NOTE: The arguments need to be optional, because some tools fetch
    # all class names. Calling #class will return the expected class.
    def class attachment = nil, style_name = nil
      return super() if attachment.nil? && style_name.nil?
      attachment.instance.class.to_s.underscore.pluralize
    end

    # Returns the basename of the file. e.g. "file" for "file.jpg"
    def basename attachment, style_name
      attachment.original_filename.gsub(/#{File.extname(attachment.original_filename)}$/, "")
    end

    # Returns the extension of the file. e.g. "jpg" for "file.jpg"
    # If the style has a format defined, it will return the format instead
    # of the actual extension.
    def extension attachment, style_name
      ((style = attachment.styles[style_name]) && style[:format]) ||
        File.extname(attachment.original_filename).gsub(/^\.+/, "")
    end

    # Returns the id of the instance.
    def id attachment, style_name
      attachment.instance.id
    end

    # Returns the fingerprint of the instance.
    def fingerprint attachment, style_name
      attachment.fingerprint
    end

    # Returns the id of the instance in a split path form. e.g. returns
    # 000/001/234 for an id of 1234.
    def id_partition attachment, style_name
      ("%09d" % attachment.instance.id).scan(/\d{3}/).join("/")
    end

    # Returns the pluralized form of the attachment name. e.g.
    # "avatars" for an attachment of :avatar
    def attachment attachment, style_name
      attachment.name.to_s.downcase.pluralize
    end

    # Returns the style, or the default style if nil is supplied.
    def style attachment, style_name
      style_name || attachment.default_style
    end
  end
end
