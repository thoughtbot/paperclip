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

  context "with :allow_nil option" do
    context "as true" do
      setup do
        build_validator :content_type => "image/png", :allow_nil => true
        @dummy.stubs(:avatar_content_type => nil)
        @validator.validate(@dummy)
      end

      should "allow avatar_content_type as nil" do
        assert @dummy.errors[:avatar_content_type].blank?
      end
    end

    context "as false" do
      setup do
        build_validator :content_type => "image/png", :allow_nil => false
        @dummy.stubs(:avatar_content_type => nil)
        @validator.validate(@dummy)
      end

      should "not allow avatar_content_type as nil" do
        assert @dummy.errors[:avatar_content_type].present?
      end
    end
  end

  context "with :allow_blank option" do
    context "as true" do
      setup do
        build_validator :content_type => "image/png", :allow_blank => true
        @dummy.stubs(:avatar_content_type => "")
        @validator.validate(@dummy)
      end

      should "allow avatar_content_type as blank" do
        assert @dummy.errors[:avatar_content_type].blank?
      end
    end

    context "as false" do
      setup do
        build_validator :content_type => "image/png", :allow_blank => false
        @dummy.stubs(:avatar_content_type => "")
        @validator.validate(@dummy)
      end

      should "not allow avatar_content_type as blank" do
        assert @dummy.errors[:avatar_content_type].present?
      end
    end
  end

  context "whitelist format" do
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
  end

  context "blacklist format" do
    context "with an allowed type" do
      context "as a string" do
        setup do
          build_validator :not => "image/gif"
          @dummy.stubs(:avatar_content_type => "image/jpg")
          @validator.validate(@dummy)
        end

        should "not set an error message" do
          assert @dummy.errors[:avatar_content_type].blank?
        end
      end

      context "as an regexp" do
        setup do
          build_validator :not => /^text\/.*/
          @dummy.stubs(:avatar_content_type => "image/jpg")
          @validator.validate(@dummy)
        end

        should "not set an error message" do
          assert @dummy.errors[:avatar_content_type].blank?
        end
      end

      context "as a list" do
        setup do
          build_validator :not => ["image/png", "image/jpg", "image/jpeg"]
          @dummy.stubs(:avatar_content_type => "image/gif")
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
          build_validator :not => "image/png"
          @dummy.stubs(:avatar_content_type => "image/png")
          @validator.validate(@dummy)
        end

        should "set a correct default error message" do
          assert @dummy.errors[:avatar_content_type].present?
          assert_includes @dummy.errors[:avatar_content_type], "is invalid"
        end
      end

      context "as a regexp" do
        setup do
          build_validator :not => /^text\/.*/
          @dummy.stubs(:avatar_content_type => "text/plain")
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
            build_validator :not => "image/png", :message => "should not be a PNG image"
            @dummy.stubs(:avatar_content_type => "image/png")
            @validator.validate(@dummy)
          end

          should "set a correct error message" do
            assert_includes @dummy.errors[:avatar_content_type], "should not be a PNG image"
          end
        end

        context "with interpolation" do
          setup do
            build_validator :not => "image/png", :message => "should not have content type %{types}"
            @dummy.stubs(:avatar_content_type => "image/png")
            @validator.validate(@dummy)
          end

          should "set a correct error message" do
            assert_includes @dummy.errors[:avatar_content_type], "should not have content type image/png"
          end
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

    should "not raise argument error if :content_type was given" do
      build_validator :content_type => "image/jpg"
    end

    should "not raise argument error if :not was given" do
      build_validator :not => "image/jpg"
    end
  end
end
