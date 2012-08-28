require './test/helper'

class UploadedFileAdapterTest < Test::Unit::TestCase
  context "a new instance" do
    context "with UploadedFile responding to #tempfile" do
      setup do
        class UploadedFile < OpenStruct; end
        tempfile = File.new(fixture_file("5k.png"))
        tempfile.binmode

        @file = UploadedFile.new(
          :original_filename => "5k.png",
          :content_type => "image/png\r",
          :head => "",
          :tempfile => tempfile,
          :path => tempfile.path
        )
        @subject = Paperclip.io_adapters.for(@file)
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
        expected = Digest::MD5.file(@file.tempfile.path).to_s
        assert_equal expected, @subject.fingerprint
      end

      should "read the contents of the file" do
        expected = @file.tempfile.read
        assert expected.length > 0
        assert_equal expected, @subject.read
      end
    end

    context "with UploadFile responding to #path" do
      setup do
        class UploadedFile < OpenStruct; end
        @file = UploadedFile.new(
          :original_filename => "5k.png",
          :content_type => "image/png",
          :head => "",
          :path => fixture_file("5k.png")
        )
        @subject = Paperclip.io_adapters.for(@file)
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
        expected_file = File.new(@file.path)
        expected_file.binmode
        expected = expected_file.read
        assert expected.length > 0
        assert_equal expected, @subject.read
      end
    end
  end
end
