require './test/helper'

class AbstractAdapterTest < Test::Unit::TestCase
  class TestAdapter < Paperclip::AbstractAdapter
    attr_accessor :path, :original_file_name, :tempfile

    def content_type
      type_from_file_command
    end
  end

  context "content type from file command" do
    setup do
      Paperclip.stubs(:run).returns("image/png\n")
    end

    should "return the content type without newline" do
      assert_equal "image/png", TestAdapter.new.content_type
    end
  end

  context "delegation" do
    setup do
      @adapter = TestAdapter.new
      @adapter.tempfile = stub("Tempfile")
    end

    context "close" do
      should "delegate to tempfile" do
        @adapter.tempfile.stubs(:close)
        @adapter.close
        assert_received @adapter.tempfile, :close
      end
    end

    context "closed?" do
      should "delegate to tempfile" do
        @adapter.tempfile.stubs(:closed?)
        @adapter.closed?
        assert_received @adapter.tempfile, :closed?
      end
    end
  end
end
