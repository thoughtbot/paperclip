require 'test/helper'

class PaperclipTest < Test::Unit::TestCase
  [:image_magick_path, :convert_path].each do |path|
    context "Calling Paperclip.run with an #{path} specified" do
      setup do
        Paperclip.options[:image_magick_path] = nil
        Paperclip.options[:convert_path]      = nil
        Paperclip.options[path]               = "/usr/bin"
      end

      should "execute the right command" do
        Paperclip.expects(:path_for_command).with("convert").returns("/usr/bin/convert")
        Paperclip.expects(:bit_bucket).returns("/dev/null")
        Paperclip.expects(:"`").with("/usr/bin/convert one.jpg two.jpg 2>/dev/null")
        Paperclip.run("convert", "one.jpg two.jpg")
      end
    end
  end

  context "Calling Paperclip.run with no path specified" do
    setup do
      Paperclip.options[:image_magick_path] = nil
      Paperclip.options[:convert_path]      = nil
    end

    should "execute the right command" do
      Paperclip.expects(:path_for_command).with("convert").returns("convert")
      Paperclip.expects(:bit_bucket).returns("/dev/null")
      Paperclip.expects(:"`").with("convert one.jpg two.jpg 2>/dev/null")
      Paperclip.run("convert", "one.jpg two.jpg")
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

  context "Paperclip.bit_bucket" do
    context "on systems without /dev/null" do
      setup do
        File.expects(:exists?).with("/dev/null").returns(false)
      end
      
      should "return 'NUL'" do
        assert_equal "NUL", Paperclip.bit_bucket
      end
    end

    context "on systems with /dev/null" do
      setup do
        File.expects(:exists?).with("/dev/null").returns(true)
      end
      
      should "return '/dev/null'" do
        assert_equal "/dev/null", Paperclip.bit_bucket
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

    context "that is valid" do
      setup do
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      should "be valid" do
        assert @dummy.valid?
      end

      context "then has a validation added that makes it invalid" do
        setup do
          assert @dummy.save
          Dummy.class_eval do
            validates_attachment_content_type :avatar, :content_type => ["text/plain"]
          end
          @dummy2 = Dummy.find(@dummy.id)
        end

        should "be invalid when reloaded" do
          assert ! @dummy2.valid?, @dummy2.errors.inspect
        end

        should "be able to call #valid? twice without having duplicate errors" do
          @dummy2.avatar.valid?
          first_errors = @dummy2.avatar.errors
          @dummy2.avatar.valid?
          assert_equal first_errors, @dummy2.avatar.errors
        end
      end
    end

    def self.should_validate validation, options, valid_file, invalid_file
      context "with #{validation} validation and #{options.inspect} options" do
        setup do
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
              assert @dummy.errors.on(:avatar)
            end
          else
            should "not have an error on the attachment" do
              assert_nil @dummy.errors.on(:avatar)
            end
          end
        end
        context "and assigned a valid file" do
          setup do
            @dummy.avatar = valid_file
            @dummy.valid?
          end
          should "not have an error when assigned a valid file" do
            assert ! @dummy.avatar.errors.key?(validation)
          end
          should "not have an error on the attachment" do
            assert_nil @dummy.errors.on(:avatar)
          end
        end
        context "and assigned an invalid file" do
          setup do
            @dummy.avatar = invalid_file
            @dummy.valid?
          end
          should "have an error when assigned a valid file" do
            assert_not_nil @dummy.avatar.errors[validation]
          end
          should "have an error on the attachment" do
            assert @dummy.errors.on(:avatar)
          end
        end
      end
    end

    [[:presence,      {},                              "5k.png",   nil],
     [:size,          {:in => 1..10240},               nil,        "12k.png"],
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

  end
end
