module Paperclip
  module Shoulda
    module Matchers
      def validate_attachment_presence name
        ValidateAttachmentPresenceMatcher.new(name)
      end

      class ValidateAttachmentPresenceMatcher
        def initialize attachment_name
          @attachment_name = attachment_name
        end

        def matches? subject
          @subject = subject
          error_when_not_valid? && no_error_when_valid?
        end

        def failure_message
          "Attachment #{@attachment_name} should be required"
        end

        def negative_failure_message
          "Attachment #{@attachment_name} should not be required"
        end

        def description
          "require presence of attachment #{@attachment_name}"
        end

        protected

        def error_when_not_valid?
          (subject = @subject.new).send(@attachment_name).assign(nil)
          subject.valid?
          not subject.errors.on(:"#{@attachment_name}_file_name").blank?
        end

        def no_error_when_valid?
          @file = StringIO.new(".")
          (subject = @subject.new).send(@attachment_name).assign(@file)
          subject.valid?
          subject.errors.on(:"#{@attachment_name}_file_name").blank?
        end
      end
    end
  end
end

