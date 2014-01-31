require './test/helper'

class ValidatorsTest < Test::Unit::TestCase
  include ActiveSupport::Testing::Deprecation

  def setup
    rebuild_model
  end

  context "using the helper" do
    setup do
      Dummy.validates_attachment :avatar, :presence => true, :content_type => { :content_type => "image/jpeg" }, :size => { :in => 0..10.kilobytes }
    end

    should "add the attachment_presence validator to the class" do
      assert Dummy.validators_on(:avatar).any?{ |validator| validator.kind == :attachment_presence }
    end

    should "add the attachment_content_type validator to the class" do
      assert Dummy.validators_on(:avatar).any?{ |validator| validator.kind == :attachment_content_type }
    end

    should "add the attachment_size validator to the class" do
      assert Dummy.validators_on(:avatar).any?{ |validator| validator.kind == :attachment_size }
    end

    should 'prevent you from attaching a file that violates that validation' do
      Dummy.class_eval{ validate(:name) { raise "DO NOT RUN THIS" } }
      dummy = Dummy.new(:avatar => File.new(fixture_file("12k.png")))
      assert_equal [:avatar_content_type, :avatar, :avatar_file_size], dummy.errors.keys
      assert_raise(RuntimeError){ dummy.valid? }
    end
  end

  context "using the helper with a conditional" do
    setup do
      Dummy.validates_attachment :avatar, :presence => true,
        :content_type => { :content_type => "image/jpeg" },
        :size => { :in => 0..10.kilobytes },
        :if => :title_present?
    end

    should "validate the attachment if title is present" do
      Dummy.class_eval do
        def title_present?
          true
        end
      end
      dummy = Dummy.new(:avatar => File.new(fixture_file("12k.png")))
      assert_equal [:avatar_content_type, :avatar, :avatar_file_size], dummy.errors.keys
    end

    should "not validate attachment if tile is not present" do
      Dummy.class_eval do
        def title_present?
          false
        end
      end
      dummy = Dummy.new(:avatar => File.new(fixture_file("12k.png")))
      assert_equal [], dummy.errors.keys
    end
  end

  context 'with no other validations on the Dummy#avatar attachment' do
    setup do
      reset_class("Dummy")
      Dummy.has_attached_file :avatar
      Paperclip.reset_duplicate_clash_check!
    end

    should 'raise an error when no content_type validation exists' do
      assert_raises(Paperclip::Errors::MissingRequiredValidatorError) do
        Dummy.new(:avatar => File.new(fixture_file("12k.png")))
      end
    end

    should 'not raise an error when a content_type validation exists' do
      Dummy.validates_attachment :avatar, :content_type => { :content_type => "image/jpeg" }

      assert_nothing_raised(Paperclip::Errors::MissingRequiredValidatorError) do 
        Dummy.new(:avatar => File.new(fixture_file("12k.png")))
      end
    end

    should 'not raise an error when a file_name validation exists' do
      Dummy.validates_attachment :avatar, :file_name => { :matches => /png$/ }

      assert_nothing_raised(Paperclip::Errors::MissingRequiredValidatorError) do 
        Dummy.new(:avatar => File.new(fixture_file("12k.png")))
      end
    end

    should 'not raise an error when a the validation has been explicitly rejected' do
      Dummy.validates_attachment :avatar, :file_type_ignorance => true

      assert_nothing_raised(Paperclip::Errors::MissingRequiredValidatorError) do
        Dummy.new(:avatar => File.new(fixture_file("12k.png")))
      end
    end
  end
end
