require './test/helper'

class ValidateAttachmentSizeMatcherTest < Test::Unit::TestCase
  context "validate_attachment_size" do
    setup do
      reset_table("dummies") do |d|
        d.string :avatar_file_name
        d.integer :avatar_file_size
      end
      @dummy_class = reset_class "Dummy"
      @dummy_class.has_attached_file :avatar
    end

    context "of limited size" do
      setup{ @matcher = self.class.validate_attachment_size(:avatar).in(256..1024) }

      context "given a class with no validation" do
        should_reject_dummy_class
      end

      context "given a class with a validation that's too high" do
        setup { @dummy_class.validates_attachment_size :avatar, :in => 256..2048 }
        should_reject_dummy_class
      end

      context "given a class with a validation that's too low" do
        setup { @dummy_class.validates_attachment_size :avatar, :in => 0..1024 }
        should_reject_dummy_class
      end

      context "given a class with a validation that matches" do
        setup { @dummy_class.validates_attachment_size :avatar, :in => 256..1024 }
        should_accept_dummy_class
      end
    end

    context "validates_attachment_size with infinite range" do
      setup{ @matcher = self.class.validate_attachment_size(:avatar) }

      context "given a class with an upper limit" do
        setup { @dummy_class.validates_attachment_size :avatar, :less_than => 1 }
        should_accept_dummy_class
      end

      context "given a class with no upper limit" do
        setup { @dummy_class.validates_attachment_size :avatar, :greater_than => 1 }
        should_accept_dummy_class
      end
    end
  end
end
