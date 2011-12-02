require './test/helper'

class AttachmentAdapterTest < Test::Unit::TestCase
  def setup
    rebuild_model :path => "tmp/:class/:attachment/:style/:filename"
    @attachment = Dummy.new.avatar
    @file = File.new(fixture_file("5k.png"))
    @attachment.assign(@file)
    @attachment.save
    @subject = Paperclip.io_adapters.for(@attachment)
  end

  should "get the right filename" do
    assert_equal "5k.png", @subject.original_filename
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
