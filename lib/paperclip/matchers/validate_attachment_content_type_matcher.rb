module Paperclip
  module Shoulda
    module Matchers
      # Ensures that the given instance or class validates the content type of
      # the given attachment as specified.
      #
      # Example:
      #   describe User do
      #     it { should validate_attachment_content_type(:icon).
      #                   allowing('image/png', 'image/gif').
      #                   rejecting('text/plain', 'text/xml') }
      #   end
      def validate_attachment_content_type name
        ValidateAttachmentContentTypeMatcher.new(name)
      end

      class ValidateAttachmentContentTypeMatcher
        def initialize attachment_name
          @attachment_name = attachment_name
          @allowed_types = []
          @rejected_types = []
        end

        def allowing *types
          @allowed_types = types.flatten
          self
        end

        def rejecting *types
          @rejected_types = types.flatten
          self
        end

        def matches? subject
          @subject = subject
          @subject = @subject.class unless Class === @subject
          @allowed_types && @rejected_types &&
          allowed_types_allowed? && rejected_types_rejected?
        end

        def failure_message
          "".tap do |str|
            str << "Content types #{@allowed_types.join(", ")} should be accepted" if @allowed_types.present?
            str << "\n" if @allowed_types.present? && @rejected_types.present?
            str << "Content types #{@rejected_types.join(", ")} should be rejected by #{@attachment_name}" if @rejected_types.present?
          end
        end

        def negative_failure_message
          "".tap do |str|
            str << "Content types #{@allowed_types.join(", ")} should be rejected" if @allowed_types.present?
            str << "\n" if @allowed_types.present? && @rejected_types.present?
            str << "Content types #{@rejected_types.join(", ")} should be accepted by #{@attachment_name}" if @rejected_types.present?
          end
        end

        def description
          "validate the content types allowed on attachment #{@attachment_name}"
        end

        protected

        def type_allowed?(type)
          file = StringIO.new(".")
          file.content_type = type
          (subject = @subject.new).attachment_for(@attachment_name).assign(file)
          subject.valid?
          subject.errors[:"#{@attachment_name}_content_type"].blank?
        end

        def allowed_types_allowed?
          @allowed_types.all? { |type| type_allowed?(type) }
        end

        def rejected_types_rejected?
          !@rejected_types.any? { |type| type_allowed?(type) }
        end
      end
    end
  end
end
