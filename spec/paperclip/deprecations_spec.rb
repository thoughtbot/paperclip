require "spec_helper"
require "aws-sdk"
require "active_support/testing/deprecation"

describe Paperclip::Deprecations do
  include ActiveSupport::Testing::Deprecation

  describe ".check" do
    before do
      ActiveSupport::Deprecation.silenced = false
    end

    context "when active record version is < 4.2" do
      it "displays deprecation warning" do
        Paperclip::Deprecations.stubs(:active_record_version).returns("4.1")

        assert_deprecated("Rails 3.2 and 4.1 are unsupported") do
          Paperclip::Deprecations.check
        end
      end
    end

    context "when active record version is 4.2" do
      it "do not display deprecation warning" do
        Paperclip::Deprecations.stubs(:active_record_version).returns("4.2")

        assert_not_deprecated do
          Paperclip::Deprecations.check
        end
      end
    end

    context "when aws sdk version is < 2" do
      before do
        ::AWS.stub! if !defined?(::Aws)
      end

      it "displays deprecation warning" do
        Paperclip::Deprecations.stubs(:aws_sdk_version).returns("1.66.0")

        assert_deprecated("AWS SDK v1 has been deprecated") do
          Paperclip::Deprecations.check
        end
      end
    end

    context "when aws sdk version is 2" do
      before do
        ::AWS.stub! if !defined?(::Aws)
      end

      it "do not display deprecation warning" do
        Paperclip::Deprecations.stubs(:aws_sdk_version).returns("2.0.0")

        assert_not_deprecated do
          Paperclip::Deprecations.check
        end
      end
    end
  end
end
