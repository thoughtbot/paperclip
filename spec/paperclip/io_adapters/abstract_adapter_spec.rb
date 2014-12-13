require 'spec_helper'

describe Paperclip::AbstractAdapter do
  class TestAdapter < Paperclip::AbstractAdapter
    attr_accessor :tempfile

    def content_type
      Paperclip::ContentTypeDetector.new(path).detect
    end
  end

  context "content type from file command" do
    before do
      @adapter = TestAdapter.new
      @adapter.stubs(:path).returns("image.png")
      Paperclip.stubs(:run).returns("image/png\n")
    end

    it "returns the content type without newline" do
      assert_equal "image/png", @adapter.content_type
    end
  end

  context "nil?" do
    it "returns false" do
      assert !TestAdapter.new.nil?
    end
  end

  context "delegation" do
    before do
      @adapter = TestAdapter.new
      @adapter.tempfile = stub("Tempfile")
    end

    [:binmode, :binmode?, :close, :close!, :closed?, :eof?, :path, :rewind, :unlink].each do |method|
      it "delegates #{method} to @tempfile" do
        @adapter.tempfile.stubs(method)
        @adapter.public_send(method)
        assert_received @adapter.tempfile, method
      end
    end
  end

  it 'gets rid of slashes and colons in filenames' do
    @adapter = TestAdapter.new
    @adapter.original_filename = "awesome/file:name.png"

    assert_equal "awesome_file_name.png", @adapter.original_filename
  end

  it 'is an assignment' do
    assert TestAdapter.new.assignment?
  end

  it 'is not nil' do
    assert !TestAdapter.new.nil?
  end

  it "generates a destination filename with no original filename" do
    @adapter = TestAdapter.new
    expect(@adapter.send(:destination).path).to_not be_nil
  end

  it 'uses the original filename to generate the tempfile' do
    @adapter = TestAdapter.new
    @adapter.original_filename = "file.png"
    expect(@adapter.send(:destination).path).to end_with(".png")
  end

  context "#original_filename=" do
    it "should not fail with a nil original filename" do
      adapter = TestAdapter.new
      expect{ adapter.original_filename = nil }.not_to raise_error
    end
  end
end
