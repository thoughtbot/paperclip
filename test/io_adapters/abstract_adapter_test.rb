require './test/helper'

class AbstractAdapterTest < Test::Unit::TestCase
  class TestAdapter < Paperclip::AbstractAdapter
    attr_accessor :tempfile

    def content_type
      Paperclip::ContentTypeDetector.new(path).detect
    end
  end

  context "content type from file command" do
    setup do
      @adapter = TestAdapter.new
      @adapter.stubs(:path).returns("image.png")
      Paperclip.stubs(:run).returns("image/png\n")
    end

    should "return the content type without newline" do
      assert_equal "image/png", @adapter.content_type
    end
  end

  context "nil?" do
    should "return false" do
      assert !TestAdapter.new.nil?
    end
  end

  context "delegation" do
    setup do
      @adapter = TestAdapter.new
      @adapter.tempfile = stub("Tempfile")
    end

    [:binmode, :binmode?, :close, :close!, :closed?, :eof?, :path, :rewind, :unlink].each do |method|
      should "delegate #{method} to @tempfile" do
        @adapter.tempfile.stubs(method)
        @adapter.public_send(method)
        assert_received @adapter.tempfile, method
      end
    end
  end

  should 'get rid of slashes and colons in filenames' do
    @adapter = TestAdapter.new
    @adapter.original_filename = "awesome/file:name.png"

    assert_equal "awesome_file_name.png", @adapter.original_filename
  end

  should 'be an assignment' do
    assert TestAdapter.new.assignment?
  end

  should 'not be nil' do
    assert !TestAdapter.new.nil?
  end
end
