require './test/helper'

class AttachmentSizeValidatorTest < Test::Unit::TestCase
  context "Model with size validation" do
    setup do
      rebuild_model
      Dummy.has_attached_file :avatar
    end

    context "without a file" do
      setup do
        Dummy.validates_attachment_size :avatar, :less_than => 10240
      end

      should "be valid" do
        assert Dummy.new.valid?
      end
    end

    context "for files below 10240 bytes" do
      setup do
        Dummy.validates_attachment_size :avatar, :less_than => 10240
      end

      should "be valid when size is below 10240 bytes" do
        assert Dummy.new(:avatar_file_size => 512).valid?
      end

      should "be invalid when too large file" do
        assert !Dummy.new(:avatar_file_size => 12345).valid?
      end
    end

    context "for files above 100 bytes" do
      setup do
        Dummy.validates_attachment_size :avatar, :greater_than => 100
      end

      should "be valid when size is above 100 bytes" do
        assert Dummy.new(:avatar_file_size => 512).valid?
      end

      should "be invalid when too small file" do
        assert !Dummy.new(:avatar_file_size => 32).valid?
      end
    end

    context "for files between 100 and 200 bytes" do
      setup do
        Dummy.validates_attachment_size :avatar, :in => 100..200
      end

      should "be valid when size is 150 bytes" do
        assert Dummy.new(:avatar_file_size => 150).valid?
      end

      should "be invalid when too small file" do
        assert !Dummy.new(:avatar_file_size => 50).valid?
      end

      should "be invalid when too large file" do
        assert !Dummy.new(:avatar_file_size => 300).valid?
      end
    end

    context "when conditional" do
      context "using if clause" do
        setup do
          Dummy.send :attr_accessor, :should_validate
          Dummy.validates_attachment_size :avatar,
            :in => 100..200, :if => :should_validate
          @dummy = Dummy.new(:avatar_file_size => 1)
        end

        should "not validate when false" do
          @dummy.should_validate = false
          assert @dummy.valid?
        end

        should "validate when true" do
          @dummy.should_validate = true
          assert !@dummy.valid?
        end
      end

      context "using unless clause" do
        setup do
          Dummy.send :attr_accessor, :should_not_validate
          Dummy.validates_attachment_size :avatar,
            :in => 100..200, :unless => :should_not_validate
          @dummy = Dummy.new(:avatar_file_size => 1)
        end

        should "not validate when true" do
          @dummy.should_not_validate = true
          assert @dummy.valid?
        end

        should "validate when false" do
          @dummy.should_not_validate = false
          assert !@dummy.valid?
        end
      end
    end
  end

  context "(error messages)" do
    setup do
      rebuild_model
    end

    should "show default error message" do
      Dummy.validates_attachment_size :avatar, :in => (100..200)
      @dummy = Dummy.new(:avatar_file_size => 1)
      @dummy.valid?

      messages = @dummy.errors[:avatar_file_size]
      assert_equal ["file size must be between 100 and 200 bytes"], messages
    end

    should "show custom error message when set in the model" do
      Dummy.validates_attachment_size :avatar, :in => (100..200),
        :message => "keep it between :min and :max bytes"
      @dummy = Dummy.new(:avatar_file_size => 1)
      @dummy.valid?

      messages = @dummy.errors[:avatar_file_size]
      assert_equal ["keep it between 100 and 200 bytes"], messages
    end

    should "show lambda error message when set in the model" do
      Dummy.validates_attachment_size :avatar, :in => (100..200),
        :message => lambda {"keep it between :min and :max bytes"}
      @dummy = Dummy.new(:avatar_file_size => 1)
      @dummy.valid?

      messages = @dummy.errors[:avatar_file_size]
      assert_equal ["keep it between 100 and 200 bytes"], messages
    end

    should "show i18n message" do
      I18n.backend.store_translations(:en,
        :paperclip => {:errors => {:size => "keep it between %{min} and %{max} bytes"}}
      )
      Dummy.validates_attachment_size :avatar, :in => (100..200)
      @dummy = Dummy.new(:avatar_file_size => 1)
      @dummy.valid?

      messages = @dummy.errors[:avatar_file_size]
      assert_equal ["keep it between 100 and 200 bytes"], messages
    end
  end
end
