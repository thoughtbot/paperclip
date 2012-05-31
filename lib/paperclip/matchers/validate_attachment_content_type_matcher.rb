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
          @subject = @subject.new if @subject.class == Class
          @allowed_types && @rejected_types &&
          allowed_types_allowed? && rejected_types_rejected?
        end

        def failure_message
          "#{@attachment_name} expected:\n".tap do |str|
            if @allowed_types.present?
              str << "Accept content types: #{@allowed_types.join(", ")}\n"
              if @missing_allowed_types.any?
                str << "  #{@missing_allowed_types.join(", ")} were rejected."
              else
                str << "  All were accepted successfully."
              end
            end
            str << "\n\n" if @allowed_types.present? && @rejected_types.present?
            if @rejected_types.present?
              str << "Reject content types: #{@rejected_types.join(", ")}"
              if @missing_allowed_types.any?
                str << "  #{@missing_rejected_types.join(", ")} were accepted."
              else
                str << "  All were rejected successfully."
              end
            end
          end
        end

        def description
          "validate the content types allowed on attachment #{@attachment_name}"
        end

        protected

        def type_allowed?(type)
          @subject.send("#{@attachment_name}_content_type=", type)
          @subject.valid?
          @subject.errors[:"#{@attachment_name}_content_type"].blank?
        end

        def allowed_types_allowed?
          @missing_allowed_types ||= @allowed_types.reject { |type| type_allowed?(type) }
          @missing_allowed_types.none?
        end

        def rejected_types_rejected?
          @missing_rejected_types ||= @rejected_types.select { |type| type_allowed?(type) }
          @missing_rejected_types.none?
        end
      end
    end
  end
end
