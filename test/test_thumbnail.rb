require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'mocha'
require 'tempfile'

require File.join(File.dirname(__FILE__), '..', 'lib', 'paperclip', 'geometry.rb')
require File.join(File.dirname(__FILE__), '..', 'lib', 'paperclip', 'thumbnail.rb')

class ThumbnailTest < Test::Unit::TestCase

  context "A Paperclip Tempfile" do
    setup do
      @tempfile = Paperclip::Tempfile.new("file.jpg")
    end

    should "have its path contain a real extension" do
      assert_equal ".jpg", File.extname(@tempfile.path)
    end

    should "be a real Tempfile" do
      assert @tempfile.is_a?(::Tempfile)
    end
  end

  context "Another Paperclip Tempfile" do
    setup do
      @tempfile = Paperclip::Tempfile.new("file")
    end

    should "not have an extension if not given one" do
      assert_equal "", File.extname(@tempfile.path)
    end

    should "still be a real Tempfile" do
      assert @tempfile.is_a?(::Tempfile)
    end
  end

  context "An image" do
    setup do
      @file = File.new(File.join(File.dirname(__FILE__), "fixtures", "5k.png"))
    end

    context "being thumbnailed at 100x50 with cropping" do
      setup do
        @thumb = Paperclip::Thumbnail.new(@file, "100x50#")
      end

      should "report its correct current and target geometries" do
        assert_equal "100x50#", @thumb.target_geometry.to_s
        assert_equal "434x66", @thumb.current_geometry.to_s
      end

      should "report its correct format" do
        assert_nil @thumb.format
      end

      should "have whiny_thumbnails turned on by default" do
        assert @thumb.whiny_thumbnails
      end

      should "send the right command to convert when sent #make" do
        @thumb.expects(:system).with do |arg|
          arg.match %r{convert\s+"#{File.expand_path(@thumb.file.path)}"\s+-scale\s+\"x50\"\s+-crop\s+\"100x50\+114\+0\"\s+\+repage\s+".*?"}
        end
        @thumb.make
      end

      should "create the thumbnail when sent #make" do
        dst = @thumb.make
        assert_match /100x50/, `identify #{dst.path}`
      end
    end
  end
end
