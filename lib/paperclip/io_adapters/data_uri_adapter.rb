module Paperclip
  class DataUriAdapter < StringioAdapter

    REGEXP = /\Adata:([-\w]+\/[-\w\+\.]+)?(?:;(charset=[\w\W]*?))?(?:;(base64))?,(.*)/m

    XML_TAG = %{<?xml version="1.0" standalone="yes"?>}

    def initialize(target_uri, options = {})
      super(extract_target(target_uri), options)
    end

    private

    def extract_target(uri)
      @data_uri_parts = (uri.match(REGEXP) || []).to_a

      @payload = get_payload_from_match
      @encoding = get_encoding_from_match
      @decoded_payload = get_decoded_payload

      if svg_image?
        @decoded_payload = generate_xml_string
      end

      StringIO.new(@decoded_payload)
    end

    def svg_image?
      @payload.start_with?("<svg")
    end

    def get_payload_from_match
      return "" if match_empty?

      if base64_encoded?
        return Base64.decode64(@data_uri_parts.last || "")
      end

      URI.unescape(@data_uri_parts.last || "")
    end

    def generate_xml_string
      [XML_TAG, @decoded_payload].flatten.join("\n")
    end

    def base64_encoded?
      return false if match_empty?

      [@data_uri_parts[2], @data_uri_parts[3]].include?("base64")
    end

    def get_encoding_from_match
      return unless charset_present?

      begin
        Encoding.find(@data_uri_parts[2].split("=").last)
      rescue ArgumentError
        default_encoding
      end
    end

    def charset_present?
      !match_empty? && @data_uri_parts[2].is_a?(String) && @data_uri_parts[2].start_with?("charset=")
    end

    def match_empty?
      @data_uri_parts.empty?
    end

    def get_decoded_payload
      return @payload unless @encoding.present?

      begin
        @payload.force_encoding(@encoding)
      rescue ArgumentError
        @payload
      end
    end

    def default_encoding
      Encoding.find("utf-8")
    end
  end
end

Paperclip.io_adapters.register Paperclip::DataUriAdapter do |target|
  String === target && target =~ Paperclip::DataUriAdapter::REGEXP
end
