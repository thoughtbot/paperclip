require './test/helper'

class ValidatorsTest < Test::Unit::TestCase
  def setup
    rebuild_model
  end

  context "using the helper" do
    setup do
      Dummy.validates_attachment :avatar, :presence => true, :content_type => { :content_type => "image/jpg" }, :size => { :in => 0..10.kilobytes }
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
  end
end
