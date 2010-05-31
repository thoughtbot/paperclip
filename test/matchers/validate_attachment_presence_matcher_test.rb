require 'test/helper'

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
  end
end
