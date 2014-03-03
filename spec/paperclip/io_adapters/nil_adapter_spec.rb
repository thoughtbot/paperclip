require 'spec_helper'

describe Paperclip::NilAdapter do
  context 'a new instance' do
    before do
      @subject = Paperclip.io_adapters.for(nil)
    end

    it "get the right filename" do
      assert_equal "", @subject.original_filename
    end

    it "get the content type" do
      assert_equal "", @subject.content_type
    end

    it "get the file's size" do
      assert_equal 0, @subject.size
    end

    it "return true for a call to nil?" do
      assert @subject.nil?
    end
  end
end
