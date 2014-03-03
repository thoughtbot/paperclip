require './test/helper'

class MetaClassTest < Minitest::Should::TestCase
  context "A meta-class of dummy" do
    setup do
      rebuild_model("Dummy")
      reset_class("Dummy")
    end

    should "be able to use Paperclip like a normal class" do
      @dummy = Dummy.new

      assert_nothing_raised do
        rebuild_meta_class_of(@dummy)
      end
    end

    should "work like any other instance" do
      @dummy = Dummy.new
      rebuild_meta_class_of(@dummy)

      assert_nothing_raised do
        @dummy.avatar = File.new(fixture_file("5k.png"), 'rb')
      end
      assert @dummy.save
    end
  end
end
