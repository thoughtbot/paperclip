require './test/helper'

class PaperclipTest < Test::Unit::TestCase
  context "Calling Paperclip.run" do
    setup do
      Paperclip.options[:image_magick_path] = nil
      Paperclip.options[:command_path]      = nil
      Paperclip::CommandLine.stubs(:'`')
    end

    should "execute the right command with :image_magick_path" do
      Paperclip.options[:image_magick_path] = "/usr/bin"
      Paperclip.expects(:log).with(includes('[DEPRECATION]'))
      Paperclip.expects(:log).with(regexp_matches(%r{/usr/bin/convert ['"]one.jpg['"] ['"]two.jpg['"]}))
      Paperclip::CommandLine.expects(:"`").with(regexp_matches(%r{/usr/bin/convert ['"]one.jpg['"] ['"]two.jpg['"]}))
      Paperclip.run("convert", ":one :two", :one => "one.jpg", :two => "two.jpg")
    end

    should "execute the right command with :command_path" do
      Paperclip.options[:command_path] = "/usr/bin"
      Paperclip::CommandLine.expects(:"`").with(regexp_matches(%r{/usr/bin/convert ['"]one.jpg['"] ['"]two.jpg['"]}))
      Paperclip.run("convert", ":one :two", :one => "one.jpg", :two => "two.jpg")
    end

    should "execute the right command with no path" do
      Paperclip::CommandLine.expects(:"`").with(regexp_matches(%r{convert ['"]one.jpg['"] ['"]two.jpg['"]}))
      Paperclip.run("convert", ":one :two", :one => "one.jpg", :two => "two.jpg")
    end

    should "tell you the command isn't there if the shell returns 127" do
      with_exitstatus_returning(127) do
        assert_raises(Paperclip::CommandNotFoundError) do
          Paperclip.run("command")
        end
      end
    end

    should "tell you the command isn't there if an ENOENT is raised" do
      assert_raises(Paperclip::CommandNotFoundError) do
        Paperclip::CommandLine.stubs(:"`").raises(Errno::ENOENT)
        Paperclip.run("command")
      end
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

  should "raise when sent #processor and the name of a class that exists but isn't a subclass of Processor" do
    assert_raises(Paperclip::PaperclipError){ Paperclip.processor(:attachment) }
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

    context "a validation with an if guard clause" do
      setup do
        Dummy.send(:"validates_attachment_presence", :avatar, :if => lambda{|i| i.foo })
        @dummy = Dummy.new
        @dummy.stubs(:avatar_file_name).returns(nil)
      end

      should "attempt validation if the guard returns true" do
        @dummy.expects(:foo).returns(true)
        assert ! @dummy.valid?
      end

      should "not attempt validation if the guard returns false" do
        @dummy.expects(:foo).returns(false)
        assert @dummy.valid?
      end
    end

    context "a validation with an unless guard clause" do
      setup do
        Dummy.send(:"validates_attachment_presence", :avatar, :unless => lambda{|i| i.foo })
        @dummy = Dummy.new
        @dummy.stubs(:avatar_file_name).returns(nil)
      end

      should "attempt validation if the guard returns true" do
        @dummy.expects(:foo).returns(false)
        assert ! @dummy.valid?
      end

      should "not attempt validation if the guard returns false" do
        @dummy.expects(:foo).returns(true)
        assert @dummy.valid?
      end
    end

    should "not have Attachment in the ActiveRecord::Base namespace" do
      assert_raises(NameError) do
        ActiveRecord::Base::Attachment
      end
    end

    def self.should_validate validation, options, valid_file, invalid_file
      context "with #{validation} validation and #{options.inspect} options" do
        setup do
          rebuild_class
          Dummy.send(:"validates_attachment_#{validation}", :avatar, options)
          @dummy = Dummy.new
        end
        context "and assigning nil" do
          setup do
            @dummy.avatar = nil
            @dummy.valid?
          end
          if validation == :presence
            should "have an error on the attachment" do
              assert @dummy.errors[:avatar_file_name]
            end
          else
            should "not have an error on the attachment" do
              assert @dummy.errors.blank?, @dummy.errors.full_messages.join(", ")
            end
          end
        end
        context "and assigned a valid file" do
          setup do
            @dummy.avatar = valid_file
            @dummy.valid?
          end
          should "not have an error when assigned a valid file" do
            assert_equal 0, @dummy.errors.length, @dummy.errors.full_messages.join(", ")
          end
        end
        context "and assigned an invalid file" do
          setup do
            @dummy.avatar = invalid_file
            @dummy.valid?
          end
          should "have an error when assigned a valid file" do
            assert @dummy.errors.length > 0
          end
        end
      end
    end

    [[:presence,      {},                              "5k.png",   nil],
     [:size,          {:in => 1..10240},               "5k.png",   "12k.png"],
     [:size,          {:less_than => 10240},           "5k.png",   "12k.png"],
     [:size,          {:greater_than => 8096},         "12k.png",  "5k.png"],
     [:content_type,  {:content_type => "image/png"},  "5k.png",   "text.txt"],
     [:content_type,  {:content_type => "text/plain"}, "text.txt", "5k.png"],
     [:content_type,  {:content_type => %r{image/.*}}, "5k.png",   "text.txt"]].each do |args|
      validation, options, valid_file, invalid_file = args
      valid_file   &&= File.open(File.join(FIXTURES_DIR, valid_file), "rb")
      invalid_file &&= File.open(File.join(FIXTURES_DIR, invalid_file), "rb")

      should_validate validation, options, valid_file, invalid_file
    end

    context "with content_type validation and lambda message" do
      context "and assigned an invalid file" do
        setup do
          Dummy.send(:"validates_attachment_content_type", :avatar, :content_type => %r{image/.*}, :message => lambda {'lambda content type message'})
          @dummy = Dummy.new
          @dummy.avatar &&= File.open(File.join(FIXTURES_DIR, "text.txt"), "rb")
          @dummy.valid?
        end

        should "have a content type error message" do
          assert [@dummy.errors[:avatar_content_type]].flatten.any?{|error| error =~ %r/lambda content type message/ }
        end
      end
    end

    context "with size validation and less_than 10240 option" do
      context "and assigned an invalid file" do
        setup do
          Dummy.send(:"validates_attachment_size", :avatar, :less_than => 10240)
          @dummy = Dummy.new
          @dummy.avatar &&= File.open(File.join(FIXTURES_DIR, "12k.png"), "rb")
          @dummy.valid?
        end

        should "have a file size min/max error message" do
          assert [@dummy.errors[:avatar_file_size]].flatten.any?{|error| error =~ %r/between 0 and 10240 bytes/ }
        end
      end
    end

    context "with size validation and less_than 10240 option with lambda message" do
      context "and assigned an invalid file" do
        setup do
          Dummy.send(:"validates_attachment_size", :avatar, :less_than => 10240, :message => lambda {'lambda between 0 and 10240 bytes'})
          @dummy = Dummy.new
          @dummy.avatar &&= File.open(File.join(FIXTURES_DIR, "12k.png"), "rb")
          @dummy.valid?
        end

        should "have a file size min/max error message" do
          assert [@dummy.errors[:avatar_file_size]].flatten.any?{|error| error =~ %r/lambda between 0 and 10240 bytes/ }
        end
      end
    end

  end
end
