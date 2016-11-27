require 'uri'

module Paperclip
  class UrlGenerator
    def initialize(attachment)
      @attachment = attachment
    end

    def for(style_name, options)
      # The presence of options[:allow_tmp] means we must return the URL of a previously
      # stored temporary upload, if found.
      if options[:allow_tmp] && saved_tmp = @attachment.matching_saved_tmp
        return interpolated = saved_tmp.tmp_url(style_name, options.except(:allow_tmp))

      # The presence of options[:tmp] means we must return the temp. URL if possible, else nil.
      elsif options[:tmp]
        if @attachment.tmp_id.nil? || @attachment.original_filename.nil?
          return nil
        else
          interpolated = attachment_options[:interpolator].interpolate(
            attachment_options[:tmp_url], @attachment, style_name
          )
        end
      else
        interpolated = attachment_options[:interpolator].interpolate(
          most_appropriate_url, @attachment, style_name,
        )
      end

      escaped = escape_url_as_needed(interpolated, options)
      timestamp_as_needed(escaped, options)
    end

    private

    attr_reader :attachment
    delegate :options, to: :attachment, prefix: true

    # This method is all over the place.
    def default_url
      if attachment_options[:default_url].respond_to?(:call)
        attachment_options[:default_url].call(@attachment)
      elsif attachment_options[:default_url].is_a?(Symbol)
        @attachment.instance.send(attachment_options[:default_url])
      else
        attachment_options[:default_url]
      end
    end

    def most_appropriate_url
      if @attachment.original_filename.nil?
        default_url
      else
        attachment_options[:url]
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
