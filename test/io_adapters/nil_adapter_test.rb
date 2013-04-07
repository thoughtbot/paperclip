require './test/helper'

class NilAdapterTest < Test::Unit::TestCase

  context "a new instance given nil" do
    should_register_with_valid_nil_adapter nil
  end

  context "a new instance given empty string" do
    should_register_with_valid_nil_adapter ''
  end

  context "a new instance given whitespace-only string" do
    should_register_with_valid_nil_adapter ' '
  end

end
