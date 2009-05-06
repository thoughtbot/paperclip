require 'test/helper'

class InterpolationsTest < Test::Unit::TestCase
  should "return all methods but the infrastructure when sent #all" do
    methods = Paperclip::Interpolations.all
    assert ! methods.include?(:[])
    assert ! methods.include?(:[]=)
    assert ! methods.include?(:all)
    methods.each do |m|
      assert Paperclip::Interpolations.respond_to? m
    end
  end

  should "return the RAILS_ROOT" do
    assert_equal RAILS_ROOT, Paperclip::Interpolations.rails_root(:attachment, :style)
  end

  should "return the RAILS_ENV" do
    assert_equal RAILS_ENV, Paperclip::Interpolations.rails_env(:attachment, :style)
  end

  should "return the class of the instance" do
    attachment = mock
    attachment.expects(:instance).returns(attachment)
    attachment.expects(:class).returns("Thing")
    assert_equal "things", Paperclip::Interpolations.class(attachment, :style)
  end

  should "return the basename of the file" do
    attachment = mock
    attachment.expects(:original_filename).returns("one.jpg").times(2)
    assert_equal "one", Paperclip::Interpolations.basename(attachment, :style)
  end

  should "return the extension of the file" do
    attachment = mock
    attachment.expects(:original_filename).returns("one.jpg")
    attachment.expects(:styles).returns({})
    assert_equal "jpg", Paperclip::Interpolations.extension(attachment, :style)
  end

  should "return the extension of the file as the format is defined in the style" do
    attachment = mock
    attachment.expects(:original_filename).never
    attachment.expects(:styles).returns({:style => {:format => "png"}})
    assert_equal "png", Paperclip::Interpolations.extension(attachment, :style)
  end

  should "return the id of the attachment" do
    attachment = mock
    attachment.expects(:id).returns(23)
    attachment.expects(:instance).returns(attachment)
    assert_equal 23, Paperclip::Interpolations.id(attachment, :style)
  end

  should "return the partitioned id of the attachment" do
    attachment = mock
    attachment.expects(:id).returns(23)
    attachment.expects(:instance).returns(attachment)
    assert_equal "000/000/023", Paperclip::Interpolations.id_partition(attachment, :style)
  end

  should "return the name of the attachment" do
    attachment = mock
    attachment.expects(:name).returns("file")
    assert_equal "files", Paperclip::Interpolations.attachment(attachment, :style)
  end

  should "return the style" do
    assert_equal :style, Paperclip::Interpolations.style(:attachment, :style)
  end

  should "return the default style" do
    attachment = mock
    attachment.expects(:default_style).returns(:default_style)
    assert_equal :default_style, Paperclip::Interpolations.style(attachment, nil)
  end
end
