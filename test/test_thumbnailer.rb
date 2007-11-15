require 'test/unit'
require File.dirname(__FILE__) + "/test_helper.rb"

class TestThumbnailer < Test::Unit::TestCase
  context "The Thumbnailer" do
    should "calculate geometries for cropping images" do
      @file = IO.read(File.join(File.dirname(__FILE__), "fixtures", "test_image.jpg"))
      assert_equal ["50x", "50x25+0+10"], Paperclip::Thumbnail.new("50x25", @file).geometry_for_crop
      assert_equal ["x50", "50x50+2+0"],  Paperclip::Thumbnail.new("50x50", @file).geometry_for_crop
      assert_equal ["x50", "25x50+14+0"], Paperclip::Thumbnail.new("25x50", @file).geometry_for_crop
    end
    
    should "be able to pipe commands" do
      doc = %w(one two three four five)
      expected = %w(five four one three two)
      assert_equal expected, Paperclip::Thumbnail.piping(doc.join("\n"), "sort").split("\n")
      assert_equal "Hello, World!\n", Paperclip::Thumbnail.piping("World", "ruby -e 'puts %Q{Hello, \#{STDIN.read}!}'")
    end
  
    [
      [:square, 125, 125],
      [:long,   53,  225],
      [:tall,   225, 53],
      [:tiny,   16,  16]
    ].each do |size, width, height|
      context "given a #{size} image" do
        setup do
          @base_file = IO.read(File.join(File.dirname(__FILE__), "fixtures", "test_image.jpg"))
          @file = Paperclip::Thumbnail.piping(@base_file, "convert - -scale '#{width}x#{height}!' -")
          assert_match /#{width}x#{height}/, Paperclip::Thumbnailer.piping(@file, "identify -")
          
          @targets = {
            :small => "50x50",
            :same => nil,
            :large => "100x100",
            :shrink_to_large => "100x100>",
            :crop_medium => "75x75#"
          }
        end
        
        should_eventually "generate correct thumbnails for the image"
      end
    end
  end
end