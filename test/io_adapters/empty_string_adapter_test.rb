require './test/helper'

class EmptyStringAdapterTest < Minitest::Should::TestCase

  context 'a new instance' do
    setup do
      @subject = Paperclip.io_adapters.for('')
    end

    should "return false for a call to nil?" do
      assert !@subject.nil?
    end

    should 'return false for a call to assignment?' do
      assert !@subject.assignment?
    end
  end
end
