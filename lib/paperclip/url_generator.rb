require 'uri'

module Paperclip
  class UrlGenerator
    def initialize(attachment, attachment_options)
      @attachment = attachment
      @attachment_options = attachment_options
    end

    def for(style_name, options)
      escape_url_as_needed(
        timestamp_as_needed(
          @attachment_options[:interpolator].interpolate(most_appropriate_url, @attachment, style_name),
          options
      ), options)
    end

    private

    # This method is all over the place.
    def default_url
      if @attachment_options[:default_url].respond_to?(:call)
        @attachment_options[:default_url].call(@attachment)
      elsif @attachment_options[:default_url].is_a?(Symbol)
        @attachment.instance.send(@attachment_options[:default_url])
      else
        @attachment_options[:default_url]
      end
    end

    def most_appropriate_url
      if @attachment.original_filename.nil?
        default_url
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
      (url.respond_to?(:escape) ? url.escape : URI.escape(url)).gsub(/(\/.+)\?(.+\.)/, '\1%3F\2')
    end
  end
end
