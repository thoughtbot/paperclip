require 'test/helper.rb'

class PaperclipTest < Test::Unit::TestCase
  context "An ActiveRecord model with an 'avatar' attachment" do
    setup do
      rebuild_model
    end

    should "have an #avatar method" do
      assert Dummy.new.respond_to?(:avatar)
    end

    should "have an #avatar= method" do
      assert Dummy.new.respond_to?(:avatar=)
    end

    [[:presence,   nil,               "5k.png", nil],
     [:size,       {:in => 1..10240}, "5k.png", "12k.png"]].each do |args|
      context "with #{args[0]} validations" do
        setup do
          Dummy.class_eval do
            send(*[:"validates_attachment_#{args[0]}", :avatar, args[1]].compact)
          end
          @dummy = Dummy.new
        end

        context "and a valid file" do
          setup do
            @file = args[2] && File.new(File.join(FIXTURES_DIR, args[2]))
          end

          should "not have any errors" do
            @dummy.avatar = @file
            assert @dummy.avatar.valid?
            assert_equal 0, @dummy.avatar.errors.length
          end
        end

        context "and an invalid file" do
          setup do
            @file = args[3] && File.new(File.join(FIXTURES_DIR, args[3]))
          end

          should "have errors" do
            @dummy.avatar = @file
            assert ! @dummy.avatar.valid?
            assert_equal 1, @dummy.avatar.errors.length
          end
        end
      end
    end
  end
end
