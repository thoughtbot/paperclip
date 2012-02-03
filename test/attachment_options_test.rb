require './test/helper'

class AttachmentOptionsTest < Test::Unit::TestCase
  should "be a Hash" do
    assert_kind_of Hash, Paperclip::AttachmentOptions.new({})
  end

  should "add a default empty validations" do
    options = {:arbi => :trary}
    expected = {:validations => []}.merge(options)
    actual = Paperclip::AttachmentOptions.new(options).to_hash
    assert_equal expected, actual
  end

  should "not override validations if passed to initializer" do
    options = {:validations => "something"}
    attachment_options = Paperclip::AttachmentOptions.new(options)
    assert_equal "something", attachment_options[:validations]
  end

  should "respond to []" do
    assert Paperclip::AttachmentOptions.new({}).respond_to?(:[])
  end

  should "deliver the specified options through []" do
    intended_options = {:specific_key => "specific value"}
    attachment_options = Paperclip::AttachmentOptions.new(intended_options)
    assert_equal "specific value", attachment_options[:specific_key]
  end

  should "respond to []=" do
    assert Paperclip::AttachmentOptions.new({}).respond_to?(:[]=)
  end

  should "remember options set with []=" do
    attachment_options = Paperclip::AttachmentOptions.new({})
    attachment_options[:foo] = "bar"
    assert_equal "bar", attachment_options[:foo]
  end
end
