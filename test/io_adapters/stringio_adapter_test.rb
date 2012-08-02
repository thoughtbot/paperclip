require './test/helper'

class StringioFileProxyTest < Test::Unit::TestCase
  context "a new instance" do
    setup do
      @contents = "abc123"
      @stringio = StringIO.new(@contents)
      @subject = Paperclip.io_adapters.for(@stringio)
    end

    should "return a file name" do
      assert_equal "stringio.txt", @subject.original_filename
    end

    should "return a content type" do
      assert_equal "text/plain", @subject.content_type
    end

    should "return the size of the data" do
      assert_equal 6, @subject.size
    end

    should "generate an MD5 hash of the contents" do
      assert_equal Digest::MD5.hexdigest(@contents), @subject.fingerprint
    end

    should "generate correct fingerprint after read" do
      fingerprint = Digest::MD5.hexdigest(@subject.read)
      assert_equal fingerprint, @subject.fingerprint
    end

    should "generate same fingerprint" do
      assert_equal @subject.fingerprint, @subject.fingerprint
    end

    should "return the data contained in the StringIO" do
      assert_equal "abc123", @subject.read
    end

    should 'accept a content_type' do
      @subject.content_type = 'image/png'
      assert_equal 'image/png', @subject.content_type
    end

    should 'accept an orgiginal_filename' do
      @subject.original_filename = 'image.png'
      assert_equal 'image.png', @subject.original_filename
    end

  end
end
