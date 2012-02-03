require './test/helper'

class ValidateAttachmentPresenceMatcherTest < Test::Unit::TestCase
  context "validate_attachment_presence" do
    setup do
      reset_table("dummies") do |d|
        d.string :avatar_file_name
      end
      @dummy_class = reset_class "Dummy"
      @dummy_class.has_attached_file :avatar
      @matcher     = self.class.validate_attachment_presence(:avatar)
    end

    context "given a class with no validation" do
      should_reject_dummy_class
    end

    context "given a class with a matching validation" do
      setup do
        @dummy_class.validates_attachment_presence :avatar
      end

      should_accept_dummy_class
    end

    context "using an :if to control the validation" do
      setup do
        @dummy_class.class_eval do
          validates_attachment_presence :avatar, :if => :go
          attr_accessor :go
        end
        @dummy = @dummy_class.new
        @dummy.avatar = nil
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
