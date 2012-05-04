require './test/helper'

class IdentityAdapterTest < Test::Unit::TestCase
  should "respond to #new by returning the argument" do
    adapter = Paperclip::IdentityAdapter.new
    assert_equal :target, adapter.new(:target)
  end
end
