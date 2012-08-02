require './test/helper'

class ValidateAttachmentContentTypeMatcherTest < Test::Unit::TestCase
  context "validate_attachment_content_type" do
    setup do
      reset_table("dummies") do |d|
        d.string :title
        d.string :avatar_file_name
        d.string :avatar_content_type
      end
      @dummy_class = reset_class "Dummy"
      @dummy_class.has_attached_file :avatar
      @matcher     = self.class.validate_attachment_content_type(:avatar).
                       allowing(%w(image/png image/jpeg)).
                       rejecting(%w(audio/mp3 application/octet-stream))
    end

    context "given a class with no validation" do
      should_reject_dummy_class
    end

    context "given a class with a validation that doesn't match" do
      setup do
        @dummy_class.validates_attachment_content_type :avatar, :content_type => %r{audio/.*}
      end

      should_reject_dummy_class
    end

    context "given a class with a matching validation" do
      setup do
        @dummy_class.validates_attachment_content_type :avatar, :content_type => %r{image/.*}
      end

      should_accept_dummy_class
    end

    context "given a class with other validations but matching types" do
      setup do
        @dummy_class.validates_presence_of :title
        @dummy_class.validates_attachment_content_type :avatar, :content_type => %r{image/.*}
      end

      should_accept_dummy_class
    end

    context "given a class that matches and a matcher that only specifies 'allowing'" do
      setup do
        @dummy_class.validates_attachment_content_type :avatar, :content_type => %r{image/.*}
        @matcher     = self.class.validate_attachment_content_type(:avatar).
          allowing(%w(image/png image/jpeg))
      end

      should_accept_dummy_class
    end

    context "given a class that does not match and a matcher that only specifies 'allowing'" do
      setup do
        @dummy_class.validates_attachment_content_type :avatar, :content_type => %r{audio/.*}
        @matcher     = self.class.validate_attachment_content_type(:avatar).
          allowing(%w(image/png image/jpeg))
      end

      should_reject_dummy_class
    end

    context "given a class that matches and a matcher that only specifies 'rejecting'" do
      setup do
        @dummy_class.validates_attachment_content_type :avatar, :content_type => %r{image/.*}
        @matcher     = self.class.validate_attachment_content_type(:avatar).
          rejecting(%w(audio/mp3 application/octet-stream))
      end

      should_accept_dummy_class
    end

    context "given a class that does not match and a matcher that only specifies 'rejecting'" do
      setup do
        @dummy_class.validates_attachment_content_type :avatar, :content_type => %r{audio/.*}
        @matcher     = self.class.validate_attachment_content_type(:avatar).
          rejecting(%w(audio/mp3 application/octet-stream))
      end

      should_reject_dummy_class
    end

    context "using an :if to control the validation" do
      setup do
        @dummy_class.class_eval do
          validates_attachment_content_type :avatar, :content_type => %r{image/*} , :if => :go
          attr_accessor :go
        end
        @matcher = self.class.validate_attachment_content_type(:avatar).
                        allowing(%w(image/png image/jpeg)).
                        rejecting(%w(audio/mp3 application/octet-stream))
        @dummy = @dummy_class.new
      end

      should "run the validation if the control is true" do
        @dummy.go = true
        assert_accepts @matcher, @dummy
      end

      should "not run the validation if the control is false" do
        @dummy.go = false
        assert_rejects @matcher, @dummy
      end
    end
  end
end
