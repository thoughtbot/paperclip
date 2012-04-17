require './test/helper'

class FileAdapterTest < Test::Unit::TestCase
  context "a new instance" do
    context "with normal file" do
      setup do
        @file = File.new(fixture_file("5k.png"))
        @file.binmode
        @subject = Paperclip.io_adapters.for(@file)
      end

      teardown { @file.close }

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
        assert expected.length > 0
        assert_equal expected, @subject.read
      end
    end

    context "empty file" do
      setup do
        @file = Tempfile.new("file_adapter_test")
        @subject = Paperclip.io_adapters.for(@file)
      end

      teardown { @file.close }

      should "provide correct mime-type" do
        assert_equal "application/x-empty", @subject.content_type
      end
    end
  end
end
