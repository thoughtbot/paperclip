require './test/helper'

class AttachmentContentTypeValidatorTest < Test::Unit::TestCase
  def setup
    rebuild_model
    @dummy = Dummy.new
  end

  def build_validator(options)
    @validator = Paperclip::Validators::AttachmentContentTypeValidator.new(options.merge(
      :attributes => :avatar
    ))
  end

  context "with a nil content type" do
    setup do
      build_validator :content_type => "image/jpg"
      @dummy.stubs(:avatar_content_type => nil)
      @validator.validate(@dummy)
    end

    should "not set an error message" do
      assert @dummy.errors[:avatar_content_type].blank?
    end
  end

  context "with an allowed type" do
    context "as a string" do
      setup do
        build_validator :content_type => "image/jpg"
        @dummy.stubs(:avatar_content_type => "image/jpg")
        @validator.validate(@dummy)
      end

      should "not set an error message" do
        assert @dummy.errors[:avatar_content_type].blank?
      end
    end

    context "as an regexp" do
      setup do
        build_validator :content_type => /^image\/.*/
        @dummy.stubs(:avatar_content_type => "image/jpg")
        @validator.validate(@dummy)
      end

      should "not set an error message" do
        assert @dummy.errors[:avatar_content_type].blank?
      end
    end
    
    context "as a list" do
      setup do
        build_validator :content_type => ["image/png", "image/jpg", "image/jpeg"]
        @dummy.stubs(:avatar_content_type => "image/jpg")
        @validator.validate(@dummy)
      end

      should "not set an error message" do
        assert @dummy.errors[:avatar_content_type].blank?
      end
    end
  end

  context "with a disallowed type" do
    context "as a string" do
      setup do
        build_validator :content_type => "image/png"
        @dummy.stubs(:avatar_content_type => "image/jpg")
        @validator.validate(@dummy)
      end

      should "set a correct default error message" do
        assert @dummy.errors[:avatar_content_type].present?
        assert_includes @dummy.errors[:avatar_content_type], "is invalid"
      end
    end

    context "as a regexp" do
      setup do
        build_validator :content_type => /^text\/.*/
        @dummy.stubs(:avatar_content_type => "image/jpg")
        @validator.validate(@dummy)
      end

      should "set a correct default error message" do
        assert @dummy.errors[:avatar_content_type].present?
        assert_includes @dummy.errors[:avatar_content_type], "is invalid"
      end
    end

    context "with :message option" do
      context "without interpolation" do
        setup do
          build_validator :content_type => "image/png", :message => "should be a PNG image"
          @dummy.stubs(:avatar_content_type => "image/jpg")
          @validator.validate(@dummy)
        end

        should "set a correct error message" do
          assert_includes @dummy.errors[:avatar_content_type], "should be a PNG image"
        end
      end

      context "with interpolation" do
        setup do
          build_validator :content_type => "image/png", :message => "should have content type %{types}"
          @dummy.stubs(:avatar_content_type => "image/jpg")
          @validator.validate(@dummy)
        end

        should "set a correct error message" do
          assert_includes @dummy.errors[:avatar_content_type], "should have content type image/png"
        end
      end
    end
  end

  context "using the helper" do
    setup do
      Dummy.validates_attachment_content_type :avatar, :content_type => "image/jpg"
    end

    should "add the validator to the class" do
      assert Dummy.validators_on(:avatar).any?{ |validator| validator.kind == :attachment_content_type }
    end
  end

  context "given options" do
    should "raise argument error if no required argument was given" do
      assert_raises(ArgumentError) do
        build_validator :message => "Some message"
      end
    end

    should "not raise arguemnt error if :content_type was given" do
      build_validator :content_type => "image/jpg"
    end
  end
end
