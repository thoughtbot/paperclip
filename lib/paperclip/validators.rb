require 'active_support/concern'
require 'paperclip/validators/attachment_content_type_validator'
require 'paperclip/validators/attachment_presence_validator'
require 'paperclip/validators/attachment_size_validator'

module Paperclip
  module Validators
    extend ActiveSupport::Concern

    included do
      extend  HelperMethods
      include HelperMethods
    end

    module ClassMethods
      # This method is a shortcut to validator classes that is in
      # "Attachment...Validator" format. It is almost the same thing as the
      # +validates+ method that shipped with Rails, but this is customized to
      # be using with attachment validators. This is helpful when you're using
      # multiple attachment validators on a single attachment.
      #
      # Example of using the validator:
      #
      #   validates_attachment :avatar, :presence => true,
      #      :content_type => { :content_type => "image/jpg" },
      #      :size => { :in => 0..10.kilobytes }
      #
      def validates_attachment(*attributes)
        options = attributes.extract_options!.dup

        Paperclip::Validators.constants.each do |constant|
          if constant.to_s =~ /^Attachment(.+)Validator$/
            validator_kind = $1.underscore.to_sym

            if options.has_key?(validator_kind)
              options[:"attachment_#{validator_kind}"] = options.delete(validator_kind)
            end
          end
        end

        validates(*attributes + [options])
      end
    end
  end
end
