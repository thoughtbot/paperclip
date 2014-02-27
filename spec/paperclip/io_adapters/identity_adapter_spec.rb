require 'spec_helper'

describe Paperclip::IdentityAdapter do
  it "respond to #new by returning the argument" do
    adapter = Paperclip::IdentityAdapter.new
    assert_equal :target, adapter.new(:target)
  end
end
