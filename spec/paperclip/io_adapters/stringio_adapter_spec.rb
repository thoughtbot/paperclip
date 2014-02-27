require 'spec_helper'

describe Paperclip::StringioAdapter do
  context "a new instance" do
    before do
      @contents = "abc123"
      @stringio = StringIO.new(@contents)
      @subject = Paperclip.io_adapters.for(@stringio)
    end

    it "return a file name" do
      assert_equal "data.txt", @subject.original_filename
    end

    it "return a content type" do
      assert_equal "text/plain", @subject.content_type
    end

    it "return the size of the data" do
      assert_equal 6, @subject.size
    end

    it "generate an MD5 hash of the contents" do
      assert_equal Digest::MD5.hexdigest(@contents), @subject.fingerprint
    end

    it "generate correct fingerprint after read" do
      fingerprint = Digest::MD5.hexdigest(@subject.read)
      assert_equal fingerprint, @subject.fingerprint
    end

    it "generate same fingerprint" do
      assert_equal @subject.fingerprint, @subject.fingerprint
    end

    it "return the data contained in the StringIO" do
      assert_equal "abc123", @subject.read
    end

    it 'accept a content_type' do
      @subject.content_type = 'image/png'
      assert_equal 'image/png', @subject.content_type
    end

    it 'accept an original_filename' do
      @subject.original_filename = 'image.png'
      assert_equal 'image.png', @subject.original_filename
    end

    it "not generate filenames that include restricted characters" do
      @subject.original_filename = 'image:restricted.png'
      assert_equal 'image_restricted.png', @subject.original_filename
    end

    it "not generate paths that include restricted characters" do
      @subject.original_filename = 'image:restricted.png'
      expect(@subject.path).to_not match(/:/)
    end

  end
end
