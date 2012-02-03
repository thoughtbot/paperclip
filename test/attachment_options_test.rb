require './test/helper'

class AttachmentOptionsTest < Test::Unit::TestCase
  should "exist" do
    Paperclip::AttachmentOptions
  end

  should "add a default empty validations" do
    options = {:arbi => :trary}
    expected = {:validations => []}.merge(options)
    actual = Paperclip::AttachmentOptions.new(options).to_hash
    assert_equal expected, actual
  end

  should "respond to []" do
    Paperclip::AttachmentOptions.new({})[:foo]
  end

  should "deliver the specified options through []" do
    intended_options = {:specific_key => "specific value"}
    attachment_options = Paperclip::AttachmentOptions.new(intended_options)
    assert_equal "specific value", attachment_options[:specific_key]
  end

  should "respond to []=" do
    Paperclip::AttachmentOptions.new({})[:foo] = "bar"
  end

  should "remember options set with []=" do
    attachment_options = Paperclip::AttachmentOptions.new({})
    attachment_options[:foo] = "bar"
    assert_equal "bar", attachment_options[:foo]
  end
end
