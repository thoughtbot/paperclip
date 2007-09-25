require 'test/unit'
require File.dirname(__FILE__) + "/test_helper.rb"
require File.dirname(__FILE__) + "/../init.rb"
require File.join(File.dirname(__FILE__), "models.rb")

class PaperclipS3Test < Test::Unit::TestCase
  def setup
  end
  
  def test_truth
    assert true
  end

end