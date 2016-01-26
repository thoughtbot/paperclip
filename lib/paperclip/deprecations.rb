require "active_support/deprecation"

module Paperclip
  class Deprecations
    class << self
      def check
        warn_aws_sdk_v1 if aws_sdk_v1?
        warn_outdated_rails if active_record_version < "4.2"
      end

      private

      def active_record_version
        ::ActiveRecord::VERSION::STRING
      end

      def aws_sdk_v1?
        defined?(::Aws) && aws_sdk_version < "2"
      end

      def warn_aws_sdk_v1
        warn "[paperclip] [deprecation] AWS SDK v1 has been deprecated in " \
             "paperclip 5. Please consider upgrading to AWS 2 before " \
             "upgrading paperclip."
      end

      def warn_outdated_rails
        warn "[paperclip] [deprecation] Rails 3.2 and 4.1 are unsupported as " \
             "of Rails 5 release. Please upgrade to Rails 4.2 before " \
             "upgrading paperclip."
      end

      def aws_sdk_version
        ::Aws::VERSION
      end

      def warn(message)
        ActiveSupport::Deprecation.warn(message)
      end
    end
  end
end
