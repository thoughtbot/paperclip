require 'spec_helper'

describe Paperclip::EmptyStringAdapter do
  context 'a new instance' do
    before do
      @subject = Paperclip.io_adapters.for('')
    end

    it "return false for a call to nil?" do
      assert !@subject.nil?
    end

    it 'return false for a call to assignment?' do
      assert !@subject.assignment?
    end
  end
end
