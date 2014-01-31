require './test/helper'

class MetaClassTest < Test::Unit::TestCase
  context "A meta-class of dummy" do
    setup do
      rebuild_model
      @file = File.new(fixture_file("5k.png"), 'rb')
    end

    teardown { @file.close }

    should "be able to use Paperclip like a normal class" do
      reset_class("Dummy")
      @dummy = Dummy.new

      assert_nothing_raised do
        rebuild_meta_class_of(@dummy)
      end
    end

    should "work like any other instance" do
      reset_class("Dummy")
      @dummy = Dummy.new
      rebuild_meta_class_of(@dummy)

      assert_nothing_raised do
        @dummy.avatar = @file
      end
      assert @dummy.save
    end
  end
end
