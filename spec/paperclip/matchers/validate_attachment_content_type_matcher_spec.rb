require 'spec_helper'
require 'paperclip/matchers'

describe Paperclip::Shoulda::Matchers::ValidateAttachmentContentTypeMatcher do
  extend Paperclip::Shoulda::Matchers

  context "validate_attachment_content_type" do
    before do
      reset_table("dummies") do |d|
        d.string :title
        d.string :avatar_file_name
        d.string :avatar_content_type
      end
      reset_class "Dummy"
      Dummy.do_not_validate_attachment_file_type :avatar
      Dummy.has_attached_file :avatar
      @matcher     = self.class.validate_attachment_content_type(:avatar).
                       allowing(%w(image/png image/jpeg)).
                       rejecting(%w(audio/mp3 application/octet-stream))
    end

    context "given a class with no validation" do
      should_reject_dummy_class
    end

    context "given a class with a validation that doesn't match" do
      before do
        Dummy.validates_attachment_content_type :avatar, content_type: %r{audio/.*}
      end

      should_reject_dummy_class
    end

    context "given a class with a matching validation" do
      before do
        Dummy.validates_attachment_content_type :avatar, content_type: %r{image/.*}
      end

      should_accept_dummy_class
    end

    context "given a class with other validations but matching types" do
      before do
        Dummy.validates_presence_of :title
        Dummy.validates_attachment_content_type :avatar, content_type: %r{image/.*}
      end

      should_accept_dummy_class
    end

    context "given a class that matches and a matcher that only specifies 'allowing'" do
      before do
        Dummy.validates_attachment_content_type :avatar, content_type: %r{image/.*}
        @matcher     = self.class.validate_attachment_content_type(:avatar).
          allowing(%w(image/png image/jpeg))
      end

      should_accept_dummy_class
    end

    context "given a class that does not match and a matcher that only specifies 'allowing'" do
      before do
        Dummy.validates_attachment_content_type :avatar, content_type: %r{audio/.*}
        @matcher     = self.class.validate_attachment_content_type(:avatar).
          allowing(%w(image/png image/jpeg))
      end

      should_reject_dummy_class
    end

    context "given a class that matches and a matcher that only specifies 'rejecting'" do
      before do
        Dummy.validates_attachment_content_type :avatar, content_type: %r{image/.*}
        @matcher     = self.class.validate_attachment_content_type(:avatar).
          rejecting(%w(audio/mp3 application/octet-stream))
      end

      should_accept_dummy_class
    end

    context "given a class that does not match and a matcher that only specifies 'rejecting'" do
      before do
        Dummy.validates_attachment_content_type :avatar, content_type: %r{audio/.*}
        @matcher     = self.class.validate_attachment_content_type(:avatar).
          rejecting(%w(audio/mp3 application/octet-stream))
      end

      should_reject_dummy_class
    end

    context "using an :if to control the validation" do
      before do
        Dummy.class_eval do
          validates_attachment_content_type :avatar, content_type: %r{image/*} , if: :go
          attr_accessor :go
        end
        @matcher = self.class.validate_attachment_content_type(:avatar).
                        allowing(%w(image/png image/jpeg)).
                        rejecting(%w(audio/mp3 application/octet-stream))
        @dummy = Dummy.new
      end

      it "run the validation if the control is true" do
        @dummy.go = true
        expect(@matcher).to accept(@dummy)
      end

      it "not run the validation if the control is false" do
        @dummy.go = false
        expect(@matcher).to_not accept(@dummy)
      end
    end
  end
end
