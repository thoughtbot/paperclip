require './test/helper'

class SinatraFileAdapterTest < Test::Unit::TestCase
  context "a new instance" do
    context "with the sinatra hash responding to [:tempfile]" do
      setup do
        tempfile = File.new(fixture_file("5k.png"))
        tempfile.binmode

        @file = {
          :filename => "5k.png",
          :type => "image/png",
          :tempfile => tempfile
        }
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
        expected = Digest::MD5.file(@file[:tempfile].path).to_s
        assert_equal expected, @subject.fingerprint
      end

      should "read the contents of the file" do
        expected = @file[:tempfile].read
        @file[:tempfile].rewind
        assert expected.length > 0
        assert_equal expected, @subject.read
      end
    end

  end
end
