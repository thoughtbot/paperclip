require './test/helper'

class DataUriAdapterTest < Test::Unit::TestCase

  def teardown
    if @subject
      @subject.close
    end
  end

  should 'allow a missing mime-type' do
    adapter = Paperclip.io_adapters.for("data:;base64,#{original_base64_content}")
    assert_equal Paperclip::DataUriAdapter, adapter.class
  end

  context "a new instance" do
    setup do
      @contents = "data:image/png;base64,#{original_base64_content}"
      @subject = Paperclip.io_adapters.for(@contents)
    end

    should "returns a file name based on the content type" do
      assert_equal "data.png", @subject.original_filename
    end

    should "return a content type" do
      assert_equal "image/png", @subject.content_type
    end

    should "return the size of the data" do
      assert_equal 4456, @subject.size
    end

    should "generate a correct MD5 hash of the contents" do
      assert_equal(
        Digest::MD5.hexdigest(Base64.decode64(original_base64_content)),
        @subject.fingerprint
      )
    end

    should "generate correct fingerprint after read" do
      fingerprint = Digest::MD5.hexdigest(@subject.read)
      assert_equal fingerprint, @subject.fingerprint
    end

    should "generate same fingerprint" do
      assert_equal @subject.fingerprint, @subject.fingerprint
    end

    should 'accept a content_type' do
      @subject.content_type = 'image/png'
      assert_equal 'image/png', @subject.content_type
    end

    should 'accept an original_filename' do
      @subject.original_filename = 'image.png'
      assert_equal 'image.png', @subject.original_filename
    end

    should "not generate filenames that include restricted characters" do
      @subject.original_filename = 'image:restricted.png'
      assert_equal 'image_restricted.png', @subject.original_filename
    end

    should "not generate paths that include restricted characters" do
      @subject.original_filename = 'image:restricted.png'
      assert_no_match /:/, @subject.path
    end

  end

  def original_base64_content
    Base64.encode64(original_file_contents)
  end

  def original_file_contents
    @original_file_contents ||= File.read(fixture_file('5k.png'))
  end
end
