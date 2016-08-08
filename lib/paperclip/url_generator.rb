require 'uri'

module Paperclip
  class UrlGenerator
    def initialize(attachment, attachment_options)
      @attachment = attachment
      @attachment_options = attachment_options
    end

    def for(style_name, options)
      timestamp_as_needed(
        escape_url_as_needed(
          @attachment_options[:interpolator].interpolate(
            most_appropriate_url(style_name),
            @attachment,
            style_name),
          options
      ), options)
    end

    private

    # This method is all over the place.
    def default_url(style_name)
      default_url = @attachment_options[:default_url]

      if default_url.respond_to?(:call)
        default_url_from_callable(default_url, style_name)
      elsif @attachment_options[:default_url].is_a?(Symbol)
        if method = @attachment.instance.method(default_url)
          default_url_from_callable(method, style_name)
        else
          @attachment.instance.send(default_url)
        end
      else
        @attachment_options[:default_url]
      end
    end

    def default_url_from_callable(callable, style_name)
      arguments = [@attachment, style_name]

      arity = callable.respond_to?(:arity) && callable.arity.abs
      arity ||= 1 # If arity unknown, call with old arguments

      callable.call(*arguments.take(arity))
    end

    def most_appropriate_url(style_name)
      if @attachment.original_filename.nil?
        default_url(style_name)
      else
        @attachment_options[:url]
      end
    end

    def timestamp_as_needed(url, options)
      if options[:timestamp] && timestamp_possible?
        delimiter_char = url.match(/\?.+=/) ? '&' : '?'
        "#{url}#{delimiter_char}#{@attachment.updated_at.to_s}"
      else
        url
      end
    end

    def timestamp_possible?
      @attachment.respond_to?(:updated_at) && @attachment.updated_at.present?
    end

    def escape_url_as_needed(url, options)
      if options[:escape]
        escape_url(url)
      else
        url
      end
    end

    def escape_url(url)
      if url.respond_to?(:escape)
        url.escape
      else
        URI.escape(url).gsub(escape_regex){|m| "%#{m.ord.to_s(16).upcase}" }
      end
    end

    def escape_regex
      /[\?\(\)\[\]\+]/
    end
  end
end
