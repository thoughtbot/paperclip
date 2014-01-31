require './test/helper'

class ValidateAttachmentSizeMatcherTest < Test::Unit::TestCase
  context "validate_attachment_size" do
    setup do
      reset_table("dummies") do |d|
        d.string :avatar_file_name
        d.integer :avatar_file_size
      end
      reset_class "Dummy"
      Dummy.do_not_validate_attachment_file_type :avatar
      Dummy.has_attached_file :avatar
    end

    context "of limited size" do
      setup{ @matcher = self.class.validate_attachment_size(:avatar).in(256..1024) }

      context "given a class with no validation" do
        should_reject_dummy_class
      end

      context "given a class with a validation that's too high" do
        setup { Dummy.validates_attachment_size :avatar, :in => 256..2048 }
        should_reject_dummy_class
      end

      context "given a class with a validation that's too low" do
        setup { Dummy.validates_attachment_size :avatar, :in => 0..1024 }
        should_reject_dummy_class
      end

      context "given a class with a validation that matches" do
        setup { Dummy.validates_attachment_size :avatar, :in => 256..1024 }
        should_accept_dummy_class
      end
    end

    context "allowing anything" do
      setup{ @matcher = self.class.validate_attachment_size(:avatar) }

      context "given a class with an upper limit" do
        setup { Dummy.validates_attachment_size :avatar, :less_than => 1 }
        should_accept_dummy_class
      end

      context "given a class with a lower limit" do
        setup { Dummy.validates_attachment_size :avatar, :greater_than => 1 }
        should_accept_dummy_class
      end
    end

    context "using an :if to control the validation" do
      setup do
        Dummy.class_eval do
          validates_attachment_size :avatar, :greater_than => 1024, :if => :go
          attr_accessor :go
        end
        @dummy = Dummy.new
        @matcher = self.class.validate_attachment_size(:avatar).greater_than(1024)
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

    context "post processing" do
      setup do
        Dummy.validates_attachment_size :avatar, :greater_than => 1024

        @dummy = Dummy.new
        @matcher = self.class.validate_attachment_size(:avatar).greater_than(1024)
      end

      should "be skipped" do
        @dummy.avatar.expects(:post_process).never
        assert_accepts @matcher, @dummy
      end
    end
  end
end
