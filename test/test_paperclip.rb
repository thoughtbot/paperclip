require 'test/helper.rb'

class PaperclipTest < Test::Unit::TestCase
  context "An ActiveRecord model with an 'avatar' attachment" do
    setup do
      rebuild_model :path => "tmp/:class/omg/:style.:extension"
      @file = File.new(File.join(FIXTURES_DIR, "5k.png"))
    end

    context "that is attr_protected" do
      setup do
        Dummy.class_eval do
          attr_protected :avatar
        end
        @dummy = Dummy.new
      end

      should "not assign the avatar on mass-set" do
        @dummy.logger.expects(:debug)

        @dummy.attributes = { :other => "I'm set!",
                              :avatar => @file }
        
        assert_equal "I'm set!", @dummy.other
        assert ! @dummy.avatar?
      end

      should "still allow assigment on normal set" do
        @dummy.logger.expects(:debug).times(0)

        @dummy.other  = "I'm set!"
        @dummy.avatar = @file
        
        assert_equal "I'm set!", @dummy.other
        assert @dummy.avatar?
      end
    end

    context "with a subclass" do
      setup do
        class ::SubDummy < Dummy; end
      end

      should "be able to use the attachment from the subclass" do
        assert_nothing_raised do
          @subdummy = SubDummy.create(:avatar => @file)
        end
      end

      should "be able to see the attachment definition from the subclass's class" do
        assert_equal "tmp/:class/omg/:style.:extension", SubDummy.attachment_definitions[:avatar][:path]
      end

      teardown do
        Object.send(:remove_const, "SubDummy") rescue nil
      end
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
