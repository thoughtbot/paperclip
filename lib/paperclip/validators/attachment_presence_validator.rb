require 'active_model/validations/presence'

module Paperclip
  module Validators
    class AttachmentPresenceValidator < ActiveModel::Validations::PresenceValidator
      def validate(record)
        [attributes].flatten.map do |attribute|
          if record.send(:read_attribute_for_validation, "#{attribute}_file_name").blank?
            record.errors.add(attribute, :blank, options)
          end
        end
      end
    end

    module HelperMethods
      # Places ActiveRecord-style validations on the presence of a file.
      # Options:
      # * +if+: A lambda or name of an instance method. Validation will only
      #   be run if this lambda or method returns true.
      # * +unless+: Same as +if+ but validates if lambda or method returns false.
      def validates_attachment_presence(*attr_names)
        validates_with AttachmentPresenceValidator, _merge_attributes(attr_names)
      end
    end
  end
end
