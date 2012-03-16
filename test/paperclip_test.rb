require './test/helper'

class PaperclipTest < Test::Unit::TestCase
  context "Calling Paperclip.run" do
    setup do
      Paperclip.options[:log_command] = false
      Cocaine::CommandLine.expects(:new).with("convert", "stuff", {}).returns(stub(:run))
      @original_command_line_path = Cocaine::CommandLine.path
    end

    teardown do
      Paperclip.options[:log_command] = true
      Cocaine::CommandLine.path = @original_command_line_path
    end

    should "run the command with Cocaine" do
      Paperclip.run("convert", "stuff")
    end

    should "save Cocaine::CommandLine.path that set before" do
      Cocaine::CommandLine.path = "/opt/my_app/bin"
      Paperclip.run("convert", "stuff")
      assert_equal [Cocaine::CommandLine.path].flatten.include?("/opt/my_app/bin"), true
    end

    should "not duplicate Cocaine::CommandLine.path on multiple runs" do
      Cocaine::CommandLine.expects(:new).with("convert", "more_stuff", {}).returns(stub(:run))
      Cocaine::CommandLine.path = nil
      Paperclip.options[:command_path] = "/opt/my_app/bin"
      Paperclip.run("convert", "stuff")
      Paperclip.run("convert", "more_stuff")
      assert_equal 1, [Cocaine::CommandLine.path].flatten.size
    end
  end

  context "Calling Paperclip.run with a logger" do
    should "pass the defined logger if :log_command is set" do
      Paperclip.options[:log_command] = true
      Cocaine::CommandLine.expects(:new).with("convert", "stuff", :logger => Paperclip.logger).returns(stub(:run))
      Paperclip.run("convert", "stuff")
    end
  end

  context "Paperclip.each_instance_with_attachment" do
    setup do
      @file = File.new(File.join(FIXTURES_DIR, "5k.png"), 'rb')
      d1 = Dummy.create(:avatar => @file)
      d2 = Dummy.create
      d3 = Dummy.create(:avatar => @file)
      @expected = [d1, d3]
    end

    should "yield every instance of a model that has an attachment" do
      actual = []
      Paperclip.each_instance_with_attachment("Dummy", "avatar") do |instance|
        actual << instance
      end
      assert_same_elements @expected, actual
    end
  end

  should "raise when sent #processor and the name of a class that doesn't exist" do
    assert_raises(NameError){ Paperclip.processor(:boogey_man) }
  end

  should "return a class when sent #processor and the name of a class under Paperclip" do
    assert_equal ::Paperclip::Thumbnail, Paperclip.processor(:thumbnail)
  end

  should "get a class from a namespaced class name" do
    class ::One; class Two; end; end
    assert_equal ::One::Two, Paperclip.class_for("One::Two")
  end

  should "raise when class doesn't exist in specified namespace" do
    class ::Three; end
    class ::Four; end
    assert_raise NameError do
      Paperclip.class_for("Three::Four")
    end
  end

  context "Attachments with clashing URLs should raise error" do
    setup do
      class Dummy2 < ActiveRecord::Base
        include Paperclip::Glue
      end
    end

    should "generate warning if attachment is redefined with the same url string" do
      expected_log_msg = "Duplicate URL for blah with /system/:id/:style/:filename. This will clash with attachment defined in Dummy class"
      Paperclip.expects(:log).with(expected_log_msg)
      Dummy.class_eval do
        has_attached_file :blah, :url => '/system/:id/:style/:filename'
      end
      Dummy2.class_eval do
        has_attached_file :blah, :url => '/system/:id/:style/:filename'
      end
    end

    should "not generate warning if attachment is redifined with the same url string but has :class in it" do
      Paperclip.expects(:log).never
      Dummy.class_eval do
        has_attached_file :blah, :url => "/system/:class/:attachment/:id/:style/:filename"
      end
      Dummy2.class_eval do
        has_attached_file :blah, :url => "/system/:class/:attachment/:id/:style/:filename"
      end
    end
  end

  context "An ActiveRecord model with an 'avatar' attachment" do
    setup do
      rebuild_model :path => "tmp/:class/omg/:style.:extension"
      @file = File.new(File.join(FIXTURES_DIR, "5k.png"), 'rb')
    end

    teardown { @file.close }

    should "not error when trying to also create a 'blah' attachment" do
      assert_nothing_raised do
        Dummy.class_eval do
          has_attached_file :blah
        end
      end
    end

    context "that is attr_protected" do
      setup do
        Dummy.class_eval do
          attr_protected :avatar
        end
        @dummy = Dummy.new
      end

      should "not assign the avatar on mass-set" do
        @dummy.attributes = { :other => "I'm set!",
                              :avatar => @file }

        assert_equal "I'm set!", @dummy.other
        assert ! @dummy.avatar?
      end

      should "still allow assigment on normal set" do
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
        assert_equal "tmp/:class/omg/:style.:extension",
                     SubDummy.attachment_definitions[:avatar][:path]
      end

      teardown do
        SubDummy.delete_all
        Object.send(:remove_const, "SubDummy") rescue nil
      end
    end

    should "have an #avatar method" do
      assert Dummy.new.respond_to?(:avatar)
    end

    should "have an #avatar= method" do
      assert Dummy.new.respond_to?(:avatar=)
    end

    context "that is valid" do
      setup do
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      should "be valid" do
        assert @dummy.valid?
      end
    end

    should "not have Attachment in the ActiveRecord::Base namespace" do
      assert_raises(NameError) do
        ActiveRecord::Base::Attachment
      end
    end
  end

  context "configuring a custom processor" do
    setup do
      @freedom_processor = Class.new do
        def make(file, options = {}, attachment = nil)
          file
        end
      end.new

      Paperclip.configure do |config|
        config.register_processor(:freedom, @freedom_processor)
      end
    end

    should "be able to find the custom processor" do
      assert_equal @freedom_processor, Paperclip.processor(:freedom)
    end

    teardown do
      Paperclip.clear_processors!
    end
  end
end
