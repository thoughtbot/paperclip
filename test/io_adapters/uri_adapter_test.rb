require './test/helper'

class UriProxyTest < Test::Unit::TestCase
  context "a new instance" do
    setup do
      @open_return = StringIO.new("xxx")
      @open_return.stubs(:content_type).returns("image/png")
      Paperclip::UriAdapter.any_instance.stubs(:download_content).returns(@open_return)
      @uri = URI.parse("http://thoughtbot.com/images/thoughtbot-logo.png")
      @subject = Paperclip.io_adapters.for(@uri)
    end

    should "return a file name" do
      assert_equal "thoughtbot-logo.png", @subject.original_filename
    end

    should 'close open handle after reading' do
      assert_equal true, @open_return.closed?
    end

    should "return a content type" do
      assert_equal "image/png", @subject.content_type
    end

    should "return the size of the data" do
      assert_equal @open_return.size, @subject.size
    end

    should "generate an MD5 hash of the contents" do
      assert_equal Digest::MD5.hexdigest("xxx"), @subject.fingerprint
    end

    should "generate correct fingerprint after read" do
      fingerprint = Digest::MD5.hexdigest(@subject.read)
      assert_equal fingerprint, @subject.fingerprint
    end

    should "generate same fingerprint" do
      assert_equal @subject.fingerprint, @subject.fingerprint
    end

    should "return the data contained in the StringIO" do
      assert_equal "xxx", @subject.read
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

  context "a directory index url" do
    setup do
      Paperclip::UriAdapter.any_instance.stubs(:download_content).returns(StringIO.new("xxx"))
      @uri = URI.parse("http://thoughtbot.com")
      @subject = Paperclip.io_adapters.for(@uri)
    end

    should "return a file name" do
      assert_equal "index.html", @subject.original_filename
    end

    should "return a content type" do
      assert_equal "text/html", @subject.content_type
    end
  end

  context "a url with query params" do
    setup do
      Paperclip::UriAdapter.any_instance.stubs(:download_content).returns(StringIO.new("xxx"))
      @uri = URI.parse("https://github.com/thoughtbot/paperclip?file=test")
      @subject = Paperclip.io_adapters.for(@uri)
    end

    should "return a file name" do
      assert_equal "paperclip", @subject.original_filename
    end
  end

  context "a url with restricted characters in the filename" do
    setup do
      Paperclip::UriAdapter.any_instance.stubs(:download_content).returns(StringIO.new("xxx"))
      @uri = URI.parse("https://github.com/thoughtbot/paper:clip.jpg")
      @subject = Paperclip.io_adapters.for(@uri)
    end

    should "not generate filenames that include restricted characters" do
      assert_equal "paper_clip.jpg", @subject.original_filename
    end

    should "not generate paths that include restricted characters" do
      assert_no_match /:/, @subject.path
    end
  end

end
