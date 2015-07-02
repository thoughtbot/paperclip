module Paperclip
  class DataUriAdapter < StringioAdapter

    REGEXP = /\Adata:([-\w]+\/[-\w\+\.]+)?;(base64|utf8),(.*)/m

    XML_TAG = %{<?xml version="1.0" standalone="yes"?>}

    def initialize(target_uri)
      super(extract_target(target_uri))
    end

    private

    def extract_target(uri)
      data_uri_parts = uri.match(REGEXP) || []
      decoded = get_image_from_match(data_uri_parts)

      if is_svg_image?(decoded)
        decoded = generate_xml_string(decoded)
      end

      StringIO.new(decoded)
    end

    def is_svg_image?(img)
      img.start_with?('<svg')
    end

    def get_image_from_match(match)
      return '' if match.length == 0

      if match[2].eql?('base64')
        return Base64.decode64(match[3] || '')
      end

      match[3] || ''
    end

    def generate_xml_string(svg)
      [XML_TAG, svg].flatten.join("\n")
    end
  end
end

Paperclip.io_adapters.register Paperclip::DataUriAdapter do |target|
  String === target && target =~ Paperclip::DataUriAdapter::REGEXP
end
