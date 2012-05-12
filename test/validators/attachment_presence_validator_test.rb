require './test/helper'

class AttachmentPresenceValidatorTest < Test::Unit::TestCase
  def setup
    rebuild_model
    @dummy = Dummy.new
  end

  def build_validator(options={})
    @validator = Paperclip::Validators::AttachmentPresenceValidator.new(options.merge(
      :attributes => :avatar
    ))
  end

  context "nil attachment" do
    setup do
      @dummy.avatar = nil
    end

    context "with default options" do
      setup do
        build_validator
        @validator.validate(@dummy)
      end

      should "add error on the attachment" do
        assert @dummy.errors[:avatar].present?
      end

      should "not add an error on the file_name attribute" do
        assert @dummy.errors[:avatar_file_name].blank?
      end
    end

    context "with :if option" do
      context "returning true" do
        setup do
          build_validator :if => true
          @validator.validate(@dummy)
        end

        should "perform a validation" do
          assert @dummy.errors[:avatar].present?
        end
      end

      context "returning false" do
        setup do
          build_validator :if => false
          @validator.validate(@dummy)
        end

        should "perform a validation" do
          assert @dummy.errors[:avatar].present?
        end
      end
    end
  end

  context "with attachment" do
    setup do
      build_validator
      @dummy.avatar = StringIO.new('.')
      @validator.validate(@dummy)
    end

    should "not add error on the attachment" do
      assert @dummy.errors[:avatar].blank?
    end

    should "not add an error on the file_name attribute" do
      assert @dummy.errors[:avatar_file_name].blank?
    end
  end

  context "using the helper" do
    setup do
      Dummy.validates_attachment_presence :avatar
    end

    should "add the validator to the class" do
      assert Dummy.validators_on(:avatar).any?{ |validator| validator.kind == :attachment_presence }
    end
  end
end
