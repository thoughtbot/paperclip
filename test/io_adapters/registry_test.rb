require './test/helper'

class AdapterRegistryTest < Test::Unit::TestCase
  context "for" do
    setup do
      class AdapterTest
        def initialize(target); end
      end
      @subject = Paperclip::AdapterRegistry.new
      @subject.register(AdapterTest){|t| Symbol === t }
    end
    should "return the class registered for the adapted type" do
      assert_equal AdapterTest, @subject.for(:target).class
    end
  end

  context "registered?" do
    setup do
      class AdapterTest
        def initialize(target); end
      end
      @subject = Paperclip::AdapterRegistry.new
      @subject.register(AdapterTest){|t| Symbol === t }
    end
    should "return true when the class of this adapter has been registered" do
      assert @subject.registered?(AdapterTest.new(:target))
    end
    should "return false when the adapter has not been registered" do
      assert ! @subject.registered?(Object)
    end
  end
end
