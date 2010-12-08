require './test/helper'

class UpfileTest < Test::Unit::TestCase
  should "return a content_type of text/plain on a real file whose content_type is determined with the file command" do
    file = File.new(File.join(File.dirname(__FILE__), "..", "LICENSE"))
    class << file
      include Paperclip::Upfile
    end
    assert_equal 'text/plain', file.content_type
  end
end
