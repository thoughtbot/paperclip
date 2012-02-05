module Paperclip
  module Shoulda
    module Matchers
      # Ensures that the given instance or class validates the presence of the
      # given attachment.
      #
      # describe User do
      #   it { should validate_attachment_presence(:avatar) }
      # end
      def validate_attachment_presence name
        ValidateAttachmentPresenceMatcher.new(name)
      end

      class ValidateAttachmentPresenceMatcher
        def initialize attachment_name
          @attachment_name = attachment_name
        end

        def matches? subject
          @subject = subject
          @subject = subject.new if subject.class == Class
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
          @subject.send(@attachment_name).assign(nil)
          @subject.valid?
          not @subject.errors[:"#{@attachment_name}_file_name"].blank?
        end

        def no_error_when_valid?
          @file = StringIO.new(".")
          @subject.send(@attachment_name).assign(@file)
          @subject.valid?
          @subject.errors[:"#{@attachment_name}_file_name"].blank?
        end
      end
    end
  end
end
