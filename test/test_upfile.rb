require 'test/unit'
require File.dirname(__FILE__) + "/test_helper.rb"

class TestUpfile < Test::Unit::TestCase
  context "Using Upfile" do
    setup do
      File.send :include, Paperclip::Upfile
      @filename = File.join(File.dirname(__FILE__), "fixtures", "test_image.jpg")
      @file = File.new(@filename)
    end
    
    should "allow File objects to respond as uploaded files do" do
      assert_respond_to @file, :original_filename
      assert_respond_to @file, :content_type
      assert_respond_to @file, :size
      assert_equal "test_image.jpg", @file.original_filename
      assert_equal "image/jpg", @file.content_type
      assert_equal @file.stat.size, @file.size
    end
  end
end