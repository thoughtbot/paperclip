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
          @attachment_options[:interpolator].interpolate(most_appropriate_url(style_name), @attachment, style_name),
          options
      ), options)
    end

    private

    # This method is all over the place.
    def determine_default_url(url)
      if url.respond_to?(:call)
        url.call(@attachment)
      elsif url.is_a?(Symbol)
        @attachment.instance.send(url)
      else
        url
      end
    end

    def default_url_for_style(style_name)
      url = @attachment_options[:default_url]

      if url.is_a?(Hash)
        url = @attachment_options[:default_url].fetch(style_name)
      end

      determine_default_url(url)
    end

    def most_appropriate_url(style_name)
      if @attachment.original_filename.nil?
        default_url_for_style(style_name)
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
