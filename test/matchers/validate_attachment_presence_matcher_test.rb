require './test/helper'

class ValidateAttachmentPresenceMatcherTest < Test::Unit::TestCase
  context "validate_attachment_presence" do
    setup do
      reset_table("dummies") do |d|
        d.string :avatar_file_name
      end
      reset_class "Dummy"
      Dummy.has_attached_file :avatar
      Dummy.do_not_validate_attachment_file_type :avatar
      @matcher     = self.class.validate_attachment_presence(:avatar)
    end

    context "given a class with no validation" do
      should_reject_dummy_class
    end

    context "given a class with a matching validation" do
      setup do
        Dummy.validates_attachment_presence :avatar
      end

      should_accept_dummy_class
    end

    context "given an instance with other attachment validations" do
      setup do
        reset_table("dummies") do |d|
          d.string :avatar_file_name
          d.string :avatar_content_type
        end

        Dummy.class_eval do
          validates_attachment_presence :avatar
          validates_attachment_content_type :avatar, :content_type => 'image/gif'
        end

        @dummy = Dummy.new
        @matcher = self.class.validate_attachment_presence(:avatar)
      end

      should "it should validate properly" do
        @dummy.avatar = File.new fixture_file('5k.png')
        assert_accepts @matcher, @dummy
      end
    end

    context "using an :if to control the validation" do
      setup do
        Dummy.class_eval do
          validates_attachment_presence :avatar, :if => :go
          attr_accessor :go
        end
        @dummy = Dummy.new
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
