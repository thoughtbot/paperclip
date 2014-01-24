require './test/helper'
require 'pp'

class AttachmentAdapterTest < Test::Unit::TestCase

  def setup
    rebuild_model :path => "tmp/:class/:attachment/:style/:filename", :styles => {:thumb => '50x50'}
    @attachment = Dummy.new.avatar
  end

  context "for an attachment" do
    setup do
      @file = File.new(fixture_file("5k.png"))
      @file.binmode

      @attachment.assign(@file)
      @attachment.save
      @subject = Paperclip.io_adapters.for(@attachment)
    end

    teardown do
      @file.close
      @subject.close
    end

    should "get the right filename" do
      assert_equal "5k.png", @subject.original_filename
    end

    should "force binmode on tempfile" do
      assert @subject.instance_variable_get("@tempfile").binmode?
    end

    should "get the content type" do
      assert_equal "image/png", @subject.content_type
    end

    should "get the file's size" do
      assert_equal 4456, @subject.size
    end

    should "return false for a call to nil?" do
      assert ! @subject.nil?
    end

    should "generate a MD5 hash of the contents" do
      expected = Digest::MD5.file(@file.path).to_s
      assert_equal expected, @subject.fingerprint
    end

    should "read the contents of the file" do
      expected = @file.read
      actual = @subject.read
      assert expected.length > 0
      assert_equal expected.length, actual.length
      assert_equal expected, actual
    end

  end

  context "for a file with restricted characters in the name" do
    setup do
      file_contents = IO.read(fixture_file("animated.gif"))
      @file = StringIO.new(file_contents)
      @file.stubs(:original_filename).returns('image:restricted.gif')
      @file.binmode

      @attachment.assign(@file)
      @attachment.save
      @subject = Paperclip.io_adapters.for(@attachment)
    end

    teardown do
      @subject.close
    end

    should "not generate paths that include restricted characters" do
      assert_no_match(/:/, @subject.path)
    end

    should "not generate filenames that include restricted characters" do
      assert_equal 'image_restricted.gif', @subject.original_filename
    end
  end

  context "for a style" do
    setup do
      @file = File.new(fixture_file("5k.png"))
      @file.binmode

      @attachment.assign(@file)

      @thumb = Tempfile.new("thumbnail").tap(&:binmode)
      FileUtils.cp @attachment.queued_for_write[:thumb].path, @thumb.path

      @attachment.save
      @subject = Paperclip.io_adapters.for(@attachment.styles[:thumb])
    end

    teardown do
      @file.close
      @thumb.close
      @subject.close
    end

    should "get the original filename" do
      assert_equal "5k.png", @subject.original_filename
    end

    should "force binmode on tempfile" do
      assert @subject.instance_variable_get("@tempfile").binmode?
    end

    should "get the content type" do
      assert_equal "image/png", @subject.content_type
    end

    should "get the thumbnail's file size" do
      assert_equal @thumb.size, @subject.size
    end

    should "return false for a call to nil?" do
      assert ! @subject.nil?
    end

    should "generate a MD5 hash of the contents" do
      expected = Digest::MD5.file(@thumb.path).to_s
      assert_equal expected, @subject.fingerprint
    end

    should "read the contents of the thumbnail" do
      @thumb.rewind
      expected = @thumb.read
      actual = @subject.read
      assert expected.length > 0
      assert_equal expected.length, actual.length
      assert_equal expected, actual
    end

  end
end
