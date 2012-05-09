require './test/helper'

class AttachmentStyleAdapterTest < Test::Unit::TestCase
  def setup
    rebuild_model :path => "tmp/:class/:attachment/:style/:filename", :styles => {:thumb => '50x50'}
    @attachment = Dummy.new.avatar
    @file = File.new(fixture_file("5k.png"))
    @file.binmode

    @attachment.assign(@file)
    
    @thumb = @attachment.queued_for_write[:thumb]
    
    @attachment.save
    @subject = Paperclip.io_adapters.for(@attachment.styles[:thumb])
  end

  def teardown
    @file.close
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
