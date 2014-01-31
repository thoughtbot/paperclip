require './test/helper'

class AttachmentFileNameValidatorTest < Test::Unit::TestCase
  def setup
    rebuild_model
    @dummy = Dummy.new
    super
  end

  def build_validator(options)
    @validator = Paperclip::Validators::AttachmentFileNameValidator.new(options.merge(
      :attributes => :avatar
    ))
  end

  context "with a failing validation" do
    setup do
      build_validator :matches => /.*\.png$/, :allow_nil => false
      @dummy.stubs(:avatar_file_name => "data.txt")
      @validator.validate(@dummy)
    end

    should "add error to the base object" do
      assert @dummy.errors[:avatar].present?,
        "Error not added to base attribute"
    end

    should "add error to base object as a string" do
      assert_kind_of String, @dummy.errors[:avatar].first,
        "Error added to base attribute as something other than a String"
    end
  end

  should "not add error to the base object with a successful validation" do
    build_validator :matches => /.*\.png$/, :allow_nil => false
    @dummy.stubs(:avatar_file_name => "image.png")
    @validator.validate(@dummy)

    assert @dummy.errors[:avatar].blank?, "Error was added to base attribute"
  end

  context "whitelist format" do
    context "with an allowed type" do
      context "as a single regexp" do
        setup do
          build_validator :matches => /.*\.jpg$/
          @dummy.stubs(:avatar_file_name => "image.jpg")
          @validator.validate(@dummy)
        end

        should "not set an error message" do
          assert @dummy.errors[:avatar_file_name].blank?
        end
      end

      context "as a list" do
        setup do
          build_validator :matches => [/.*\.png$/, /.*\.jpe?g$/]
          @dummy.stubs(:avatar_file_name => "image.jpg")
          @validator.validate(@dummy)
        end

        should "not set an error message" do
          assert @dummy.errors[:avatar_file_name].blank?
        end
      end
    end

    context "with a disallowed type" do
      should "set a correct default error message" do
        build_validator :matches => /^text\/.*/
        @dummy.stubs(:avatar_file_name => "image.jpg")
        @validator.validate(@dummy)

        assert @dummy.errors[:avatar_file_name].present?
        assert_includes @dummy.errors[:avatar_file_name], "is invalid"
      end

      should "set a correct custom error message" do
        build_validator :matches => /.*\.png$/, :message => "should be a PNG image"
        @dummy.stubs(:avatar_file_name => "image.jpg")
        @validator.validate(@dummy)

        assert_includes @dummy.errors[:avatar_file_name], "should be a PNG image"
      end
    end
  end

  context "blacklist format" do
    context "with an allowed type" do
      context "as a single regexp" do
        setup do
          build_validator :not => /^text\/.*/
          @dummy.stubs(:avatar_file_name => "image.jpg")
          @validator.validate(@dummy)
        end

        should "not set an error message" do
          assert @dummy.errors[:avatar_file_name].blank?
        end
      end

      context "as a list" do
        setup do
          build_validator :not => [/.*\.png$/, /.*\.jpe?g$/]
          @dummy.stubs(:avatar_file_name => "image.gif")
          @validator.validate(@dummy)
        end

        should "not set an error message" do
          assert @dummy.errors[:avatar_file_name].blank?
        end
      end
    end

    context "with a disallowed type" do
      should "set a correct default error message" do
        build_validator :not => /data.*/
        @dummy.stubs(:avatar_file_name => "data.txt")
        @validator.validate(@dummy)

        assert @dummy.errors[:avatar_file_name].present?
        assert_includes @dummy.errors[:avatar_file_name], "is invalid"
      end

      should "set a correct custom error message" do
        build_validator :not => /.*\.png$/, :message => "should not be a PNG image"
        @dummy.stubs(:avatar_file_name => "image.png")
        @validator.validate(@dummy)

        assert_includes @dummy.errors[:avatar_file_name], "should not be a PNG image"
      end
    end
  end

  context "using the helper" do
    setup do
      Dummy.validates_attachment_file_name :avatar, :matches => /.*\.jpg$/
    end

    should "add the validator to the class" do
      assert Dummy.validators_on(:avatar).any?{ |validator| validator.kind == :attachment_file_name }
    end
  end

  context "given options" do
    should "raise argument error if no required argument was given" do
      assert_raises(ArgumentError) do
        build_validator :message => "Some message"
      end
    end

    should "not raise argument error if :matches was given" do
      build_validator :matches => /.*\.jpg$/
    end

    should "not raise argument error if :not was given" do
      build_validator :not => /.*\.jpg$/
    end
  end
end

