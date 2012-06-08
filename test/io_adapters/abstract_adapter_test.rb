require './test/helper'

class AbstractAdapterTest < Test::Unit::TestCase
  class TestAdapter < Paperclip::AbstractAdapter
    attr_accessor :path, :original_file_name

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
end
