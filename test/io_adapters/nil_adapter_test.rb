require './test/helper'

class NilAdapterTest < Test::Unit::TestCase
  [nil,''].each do |given_attachment|
    context "a new instance given #{given_attachment.nil? ? 'nil' : "''"}" do
      setup do
        @subject = Paperclip.io_adapters.for(given_attachment)
      end

      should "get the right filename" do
        assert_equal "", @subject.original_filename
      end

      should "get the content type" do
        assert_equal "", @subject.content_type
      end

      should "get the file's size" do
        assert_equal 0, @subject.size
      end

      should "return true for a call to nil?" do
        assert @subject.nil?
      end
    end
  end
end
