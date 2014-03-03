require 'spec_helper'

describe Paperclip::Validators do
  context "using the helper" do
    before do
      Dummy.validates_attachment :avatar, :presence => true, :content_type => { :content_type => "image/jpeg" }, :size => { :in => 0..10240 }
    end

    it "adds the attachment_presence validator to the class" do
      assert Dummy.validators_on(:avatar).any?{ |validator| validator.kind == :attachment_presence }
    end

    it "adds the attachment_content_type validator to the class" do
      assert Dummy.validators_on(:avatar).any?{ |validator| validator.kind == :attachment_content_type }
    end

    it "adds the attachment_size validator to the class" do
      assert Dummy.validators_on(:avatar).any?{ |validator| validator.kind == :attachment_size }
    end

    it 'prevents you from attaching a file that violates that validation' do
      I18n.enforce_available_locales = false
      Dummy.class_eval{ validate(:name) { raise "DO NOT RUN THIS" } }
      dummy = Dummy.new(:avatar => File.new(fixture_file("12k.png")))
      assert_equal [:avatar_content_type, :avatar, :avatar_file_size], dummy.errors.keys
      assert_raises(RuntimeError){ dummy.valid? }
    end
  end

  context "using the helper with a conditional" do
    before do
      rebuild_class
      Dummy.validates_attachment :avatar, :presence => true,
        :content_type => { :content_type => "image/jpeg" },
        :size => { :in => 0..10240 },
        :if => :title_present?
    end

    it "validates the attachment if title is present" do
      Dummy.class_eval do
        def title_present?
          true
        end
      end
      dummy = Dummy.new(:avatar => File.new(fixture_file("12k.png")))
      assert_equal [:avatar_content_type, :avatar, :avatar_file_size], dummy.errors.keys
    end

    it "does not validate attachment if title is not present" do
      Dummy.class_eval do
        def title_present?
          false
        end
      end
      dummy = Dummy.new(avatar: File.new(fixture_file("12k.png")))
      assert_equal [], dummy.errors.keys
    end
  end

  context 'with no other validations on the Dummy#avatar attachment' do
    before do
      reset_class("Dummy")
      Dummy.has_attached_file :avatar
      Paperclip.reset_duplicate_clash_check!
    end

    it 'raises an error when no content_type validation exists' do
      assert_raises(Paperclip::Errors::MissingRequiredValidatorError) do
        Dummy.new(:avatar => File.new(fixture_file("12k.png")))
      end
    end

    it 'does not raise an error when a content_type validation exists' do
      Dummy.validates_attachment :avatar, :content_type => { :content_type => "image/jpeg" }

      assert_nothing_raised do
        Dummy.new(:avatar => File.new(fixture_file("12k.png")))
      end
    end

    it 'does not raise an error when a file_name validation exists' do
      Dummy.validates_attachment :avatar, :file_name => { :matches => /png$/ }

      assert_nothing_raised do
        Dummy.new(:avatar => File.new(fixture_file("12k.png")))
      end
    end

    it 'does not raise an error when a the validation has been explicitly rejected' do
      Dummy.validates_attachment :avatar, :file_type_ignorance => true

      assert_nothing_raised do
        Dummy.new(:avatar => File.new(fixture_file("12k.png")))
      end
    end
  end
end
