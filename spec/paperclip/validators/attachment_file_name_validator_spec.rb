require 'spec_helper'

describe Paperclip::Validators::AttachmentFileNameValidator do
  before do
    rebuild_model
    @dummy = Dummy.new
  end

  def build_validator(options)
    @validator = Paperclip::Validators::AttachmentFileNameValidator.new(options.merge(
      attributes: :avatar
    ))
  end

  context "with a failing validation" do
    before do
      build_validator matches: /.*\.png$/, allow_nil: false
      @dummy.stubs(avatar_file_name: "data.txt")
      @validator.validate(@dummy)
    end

    it "adds error to the base object" do
      assert @dummy.errors[:avatar].present?,
        "Error not added to base attribute"
    end

    it "adds error to base object as a string" do
      expect(@dummy.errors[:avatar].first).to be_a String
    end
  end

  context "with add_validation_errors_to not set (implicitly :both)" do
    it "adds error to both attribute and base" do
      build_validator matches: /.*\.png$/, allow_nil: false
      @dummy.stubs(avatar_file_name: "data.txt")
      @validator.validate(@dummy)

      assert @dummy.errors[:avatar_file_name].present?,
        "Error not added to attribute"

      assert @dummy.errors[:avatar].present?,
        "Error not added to base attribute"
    end
  end

  context "with add_validation_errors_to set to :attribute globally" do
    before do
      Paperclip.options[:add_validation_errors_to] = :attribute
    end

    after do
      Paperclip.options[:add_validation_errors_to] = :both
    end

    it "only adds error to attribute not base" do
      build_validator matches: /.*\.png$/, allow_nil: false
      @dummy.stubs(avatar_file_name: "data.txt")
      @validator.validate(@dummy)

      assert @dummy.errors[:avatar_file_name].present?,
        "Error not added to attribute"

      assert @dummy.errors[:avatar].blank?,
        "Error added to base attribute"
    end
  end

  context "with add_validation_errors_to set to :base globally" do
    before do
      Paperclip.options[:add_validation_errors_to] = :base
    end

    after do
      Paperclip.options[:add_validation_errors_to] = :both
    end

    it "only adds error to base not attribute" do
      build_validator matches: /.*\.png$/, allow_nil: false
      @dummy.stubs(avatar_file_name: "data.txt")
      @validator.validate(@dummy)

      assert @dummy.errors[:avatar].present?,
        "Error not added to base attribute"

      assert @dummy.errors[:avatar_file_name].blank?,
        "Error added to attribute"
    end
  end

  context "with add_validation_errors_to set to :attribute" do
    it "only adds error to attribute not base" do
      build_validator matches: /.*\.png$/, allow_nil: false,
        add_validation_errors_to: :attribute
      @dummy.stubs(avatar_file_name: "data.txt")
      @validator.validate(@dummy)

      assert @dummy.errors[:avatar_file_name].present?,
        "Error not added to attribute"

      assert @dummy.errors[:avatar].blank?,
        "Error added to base attribute"
    end
  end

  context "with add_validation_errors_to set to :base" do
    it "only adds error to base not attribute" do
      build_validator matches: /.*\.png$/, allow_nil: false,
        add_validation_errors_to: :base
      @dummy.stubs(avatar_file_name: "data.txt")
      @validator.validate(@dummy)

      assert @dummy.errors[:avatar].present?,
        "Error not added to base attribute"

      assert @dummy.errors[:avatar_file_name].blank?,
        "Error added to attribute"
    end
  end

  it "does not add error to the base object with a successful validation" do
    build_validator matches: /.*\.png$/, allow_nil: false
    @dummy.stubs(avatar_file_name: "image.png")
    @validator.validate(@dummy)

    assert @dummy.errors[:avatar].blank?, "Error was added to base attribute"
  end

  context "whitelist format" do
    context "with an allowed type" do
      context "as a single regexp" do
        before do
          build_validator matches: /.*\.jpg$/
          @dummy.stubs(avatar_file_name: "image.jpg")
          @validator.validate(@dummy)
        end

        it "does not set an error message" do
          assert @dummy.errors[:avatar_file_name].blank?
        end
      end

      context "as a list" do
        before do
          build_validator matches: [/.*\.png$/, /.*\.jpe?g$/]
          @dummy.stubs(avatar_file_name: "image.jpg")
          @validator.validate(@dummy)
        end

        it "does not set an error message" do
          assert @dummy.errors[:avatar_file_name].blank?
        end
      end
    end

    context "with a disallowed type" do
      it "sets a correct default error message" do
        build_validator matches: /^text\/.*/
        @dummy.stubs(avatar_file_name: "image.jpg")
        @validator.validate(@dummy)

        assert @dummy.errors[:avatar_file_name].present?
        expect(@dummy.errors[:avatar_file_name]).to include "is invalid"
      end

      it "sets a correct custom error message" do
        build_validator matches: /.*\.png$/, message: "should be a PNG image"
        @dummy.stubs(avatar_file_name: "image.jpg")
        @validator.validate(@dummy)

        expect(@dummy.errors[:avatar_file_name]).to include "should be a PNG image"
      end
    end
  end

  context "blacklist format" do
    context "with an allowed type" do
      context "as a single regexp" do
        before do
          build_validator not: /^text\/.*/
          @dummy.stubs(avatar_file_name: "image.jpg")
          @validator.validate(@dummy)
        end

        it "does not set an error message" do
          assert @dummy.errors[:avatar_file_name].blank?
        end
      end

      context "as a list" do
        before do
          build_validator not: [/.*\.png$/, /.*\.jpe?g$/]
          @dummy.stubs(avatar_file_name: "image.gif")
          @validator.validate(@dummy)
        end

        it "does not set an error message" do
          assert @dummy.errors[:avatar_file_name].blank?
        end
      end
    end

    context "with a disallowed type" do
      it "sets a correct default error message" do
        build_validator not: /data.*/
        @dummy.stubs(avatar_file_name: "data.txt")
        @validator.validate(@dummy)

        assert @dummy.errors[:avatar_file_name].present?
        expect(@dummy.errors[:avatar_file_name]).to include "is invalid"
      end

      it "sets a correct custom error message" do
        build_validator not: /.*\.png$/, message: "should not be a PNG image"
        @dummy.stubs(avatar_file_name: "image.png")
        @validator.validate(@dummy)

        expect(@dummy.errors[:avatar_file_name]).to include "should not be a PNG image"
      end
    end
  end

  context "using the helper" do
    before do
      Dummy.validates_attachment_file_name :avatar, matches: /.*\.jpg$/
    end

    it "adds the validator to the class" do
      assert Dummy.validators_on(:avatar).any?{ |validator| validator.kind == :attachment_file_name }
    end
  end

  context "given options" do
    it "raises argument error if no required argument was given" do
      assert_raises(ArgumentError) do
        build_validator message: "Some message"
      end
    end

    it "does not raise argument error if :matches was given" do
      build_validator matches: /.*\.jpg$/
    end

    it "does not raise argument error if :not was given" do
      build_validator not: /.*\.jpg$/
    end
  end
end

