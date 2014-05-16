require 'spec_helper'

describe Paperclip::FileCommandContentTypeDetector do
  it 'returns a content type based on the content of the file' do
    tempfile = Tempfile.new("something")
    tempfile.write("This is a file.")
    tempfile.rewind

    assert_equal "text/plain", Paperclip::FileCommandContentTypeDetector.new(tempfile.path).detect

    tempfile.close
  end

  it 'returns a sensible default when the file command is missing' do
    Paperclip.stubs(:run).raises(Cocaine::CommandLineError.new)
    @filename = "/path/to/something"
    assert_equal "application/octet-stream",
      Paperclip::FileCommandContentTypeDetector.new(@filename).detect
  end

  it 'returns a sensible default on the odd chance that run returns nil' do
    Paperclip.stubs(:run).returns(nil)
    assert_equal "application/octet-stream",
      Paperclip::FileCommandContentTypeDetector.new("windows").detect
  end
end
