require 'active_model'
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

        attributes.each do |attribute|
          process_validation(attribute, options.dup)
        end

        validates(*attributes + [options])
      end

      def process_validation(attribute, validations)
        send(:"before_#{attribute}_post_process") do |*args|
          validations.each do |validator_name, validator_args|
            validator_args = {} if validator_args == true
            validator_args = validator_args.merge(:attributes => [attribute])
            validator = Paperclip::Validators.const_get("#{validator_name}_validator".classify)
            validator.new(validator_args).validate_each(self, attribute, send(attribute))
          end

          !self.errors.any?
        end
      end

    end
  end
end
