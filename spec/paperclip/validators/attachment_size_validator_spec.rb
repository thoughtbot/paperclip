require 'spec_helper'

describe Paperclip::Validators::AttachmentSizeValidator do
  before do
    rebuild_model
    @dummy = Dummy.new
  end

  def build_validator(options)
    @validator = Paperclip::Validators::AttachmentSizeValidator.new(options.merge(
      attributes: :avatar
    ))
  end

  def self.storage_units
    if defined?(ActiveSupport::NumberHelper) # Rails 4.0+
      { 5120 => '5 KB',       10240 => '10 KB' }
    else
      { 5120 => '5120 Bytes', 10240 => '10240 Bytes' }
    end
  end

  def self.should_allow_attachment_file_size(size)
    context "when the attachment size is #{size}" do
      it "does not add error to the dummy object" do
        @dummy.stubs(:avatar_file_size).returns(size)
        @validator.validate(@dummy)
        assert @dummy.errors[:avatar_file_size].blank?,
          "Error added to :avatar_file_size"
      end

      it "does not add error to the base dummy object" do
        @validator.validate(@dummy)
        assert @dummy.errors[:avatar].blank?,
          "Error added to base attribute"
      end
    end
  end

  def self.should_not_allow_attachment_file_size(size, options = {})
    context "when the attachment size is #{size}" do
      before do
        @dummy.stubs(:avatar_file_size).returns(size)
        @validator.validate(@dummy)
      end

      it "adds error to dummy object" do
        assert @dummy.errors[:avatar_file_size].present?,
          "Error not added to :avatar_file_size"
      end

      it "adds error to the base dummy object" do
        assert @dummy.errors[:avatar].present?,
          "Error not added to base attribute"
      end

      it "adds error to base object as a string" do
        expect(@dummy.errors[:avatar].first).to be_a String
      end

      if options[:message]
        it "returns a correct error message" do
          expect(@dummy.errors[:avatar_file_size]).to include options[:message]
        end
      end
    end
  end

  context "with :in option" do
    context "as a range" do
      before do
        build_validator in: (5.kilobytes..10.kilobytes)
      end

      should_allow_attachment_file_size(7.kilobytes)
      should_not_allow_attachment_file_size(4.kilobytes)
      should_not_allow_attachment_file_size(11.kilobytes)
    end

    context "as a proc" do
      before do
        build_validator in: lambda { |avatar| (5.kilobytes..10.kilobytes) }
      end

      should_allow_attachment_file_size(7.kilobytes)
      should_not_allow_attachment_file_size(4.kilobytes)
      should_not_allow_attachment_file_size(11.kilobytes)
    end
  end

  context "with :greater_than option" do
    context "as number" do
      before do
        build_validator greater_than: 10.kilobytes
      end

      should_allow_attachment_file_size 11.kilobytes
      should_not_allow_attachment_file_size 10.kilobytes
    end

    context "as a proc" do
      before do
        build_validator greater_than: lambda { |avatar| 10.kilobytes }
      end

      should_allow_attachment_file_size 11.kilobytes
      should_not_allow_attachment_file_size 10.kilobytes
    end
  end

  context "with :less_than option" do
    context "as number" do
      before do
        build_validator less_than: 10.kilobytes
      end

      should_allow_attachment_file_size 9.kilobytes
      should_not_allow_attachment_file_size 10.kilobytes
    end

    context "as a proc" do
      before do
        build_validator less_than: lambda { |avatar| 10.kilobytes }
      end

      should_allow_attachment_file_size 9.kilobytes
      should_not_allow_attachment_file_size 10.kilobytes
    end
  end

  context "with :greater_than and :less_than option" do
    context "as numbers" do
      before do
        build_validator greater_than: 5.kilobytes,
          less_than: 10.kilobytes
      end

      should_allow_attachment_file_size 7.kilobytes
      should_not_allow_attachment_file_size 5.kilobytes
      should_not_allow_attachment_file_size 10.kilobytes
    end

    context "as a proc" do
      before do
        build_validator greater_than: lambda { |avatar| 5.kilobytes },
          less_than: lambda { |avatar| 10.kilobytes }
      end

      should_allow_attachment_file_size 7.kilobytes
      should_not_allow_attachment_file_size 5.kilobytes
      should_not_allow_attachment_file_size 10.kilobytes
    end
  end

  context "with :message option" do
    context "given a range" do
      before do
        build_validator in: (5.kilobytes..10.kilobytes),
          message: "is invalid. (Between %{min} and %{max} please.)"
      end

      should_not_allow_attachment_file_size 11.kilobytes,
        message: "is invalid. (Between #{storage_units[5120]} and #{storage_units[10240]} please.)"
    end

    context "given :less_than and :greater_than" do
      before do
        build_validator less_than: 10.kilobytes,
          greater_than: 5.kilobytes,
          message: "is invalid. (Between %{min} and %{max} please.)"
      end

      should_not_allow_attachment_file_size 11.kilobytes,
        message: "is invalid. (Between #{storage_units[5120]} and #{storage_units[10240]} please.)"
    end
  end

  context "default error messages" do
    context "given :less_than and :greater_than" do
      before do
        build_validator greater_than: 5.kilobytes,
          less_than: 10.kilobytes
      end

      should_not_allow_attachment_file_size 11.kilobytes,
        message: "must be less than #{storage_units[10240]}"
      should_not_allow_attachment_file_size 4.kilobytes,
        message: "must be greater than #{storage_units[5120]}"
    end

    context "given a size range" do
      before do
        build_validator in: (5.kilobytes..10.kilobytes)
      end

      should_not_allow_attachment_file_size 11.kilobytes,
        message: "must be in between #{storage_units[5120]} and #{storage_units[10240]}"
      should_not_allow_attachment_file_size 4.kilobytes,
        message: "must be in between #{storage_units[5120]} and #{storage_units[10240]}"
    end
  end

  context "when invalid" do
    context "by default" do
      before do
        Paperclip.options[:duplicate_errors_on_base] = true
        build_validator in: (5.kilobytes..10.kilobytes)
        @dummy.stubs(:avatar_file_size).returns(1.kilobyte)
        @validator.validate(@dummy)
      end
      it "adds error to the base attribute" do
        assert @dummy.errors[:avatar].present?,
               "Error not added to base attribute"
      end
      it "adds errors on the attribute" do
        assert @dummy.errors[:avatar_file_size].present?,
               "Error not added to attribute"
      end
    end

    context "with :duplicate_errors_on_base global option set" do
      after do
        Paperclip.unstub(:options)
      end

      context "when global option is set to true" do
        before do
          Paperclip.stubs(:options).returns(duplicate_errors_on_base: true)
          build_validator in: (5.kilobytes..10.kilobytes)
          @dummy.stubs(:avatar_file_size).returns(1.kilobyte)
          @validator.validate(@dummy)
        end

        it "adds error to the base object" do
          assert @dummy.errors[:avatar].present?,
            "Error not added to base attribute"
        end

        it "adds errors on the attribute" do
          assert @dummy.errors[:avatar_file_size].present?,
                 "Error not added to attribute"
        end
      end

      context "when global option is set to false" do
        before do
          Paperclip.stubs(:options).returns(duplicate_errors_on_base: false)
          build_validator in: (5.kilobytes..10.kilobytes)
          @dummy.stubs(:avatar_file_size).returns(1.kilobyte)
          @validator.validate(@dummy)
        end

        it "does not add errors to the base object" do
          expect(@dummy.errors[:avatar]).to be_empty
        end

        it "adds errors on the attribute" do
          assert @dummy.errors[:avatar_file_size].present?,
            "Error not added to attribute"
        end
      end

      context "when global option is set to false but :duplicate_errors_on_base is set to true in the validator" do
        before do
          Paperclip.stubs(:options).returns(duplicate_errors_on_base: false)
          build_validator in: (5.kilobytes..10.kilobytes), duplicate_errors_on_base: true
          @dummy.stubs(:avatar_file_size).returns(1.kilobyte)
          @validator.validate(@dummy)
        end

        it "adds error to the base object" do
          assert @dummy.errors[:avatar].present?,
                 "Error not added to base attribute"
        end

        it "adds errors on the attribute" do
          assert @dummy.errors[:avatar_file_size].present?,
                 "Error not added to attribute"
        end
      end

      context "when global option is set to true but :duplicate_errors_on_base is set to false in the validator" do
        before do
          Paperclip.stubs(:options).returns(duplicate_errors_on_base: true)
          build_validator in: (5.kilobytes..10.kilobytes),
                          duplicate_errors_on_base: false
          @dummy.stubs(:avatar_file_size).returns(1.kilobyte)
          @validator.validate(@dummy)
        end

        it "does not add error to the base object" do
          assert @dummy.errors[:avatar].blank?,
                 "Error added to base attribute"
        end

        it "adds errors on the attribute" do
          assert @dummy.errors[:avatar_file_size].present?,
                 "Error not added to attribute"
        end
      end
    end

  end

  context "using the helper" do
    before do
      Dummy.validates_attachment_size :avatar, in: (5.kilobytes..10.kilobytes)
    end

    it "adds the validator to the class" do
      assert Dummy.validators_on(:avatar).any?{ |validator| validator.kind == :attachment_size }
    end
  end

  context "given options" do
    it "raises argument error if no required argument was given" do
      assert_raises(ArgumentError) do
        build_validator message: "Some message"
      end
    end

    (Paperclip::Validators::AttachmentSizeValidator::AVAILABLE_CHECKS).each do |argument|
      it "does not raise arguemnt error if #{argument} was given" do
        build_validator argument => 5.kilobytes
      end
    end

    it "does not raise argument error if :in was given" do
      build_validator in: (5.kilobytes..10.kilobytes)
    end
  end
end
