require 'test/helper'

class Dummy
  # This is a dummy class
end

class AttachmentTest < Test::Unit::TestCase
  context "Attachment default_options" do
    setup do
      rebuild_model
      @old_default_options = Paperclip::Attachment.default_options.dup
      @new_default_options = @old_default_options.merge({
        :path => "argle/bargle",
        :url => "fooferon",
        :default_url => "not here.png"
      })
    end

    teardown do
      Paperclip::Attachment.default_options.merge! @old_default_options
    end

    should "be overrideable" do
      Paperclip::Attachment.default_options.merge!(@new_default_options)
      @new_default_options.keys.each do |key|
        assert_equal @new_default_options[key],
                     Paperclip::Attachment.default_options[key]
      end
    end

    context "without an Attachment" do
      setup do
        @dummy = Dummy.new
      end
      
      should "return false when asked exists?" do
        assert !@dummy.avatar.exists?
      end
    end

    context "on an Attachment" do
      setup do
        @dummy = Dummy.new
        @attachment = @dummy.avatar
      end

      Paperclip::Attachment.default_options.keys.each do |key|
        should "be the default_options for #{key}" do
          assert_equal @old_default_options[key], 
                       @attachment.instance_variable_get("@#{key}"),
                       key
        end
      end

      context "when redefined" do
        setup do
          Paperclip::Attachment.default_options.merge!(@new_default_options)
          @dummy = Dummy.new
          @attachment = @dummy.avatar
        end

        Paperclip::Attachment.default_options.keys.each do |key|
          should "be the new default_options for #{key}" do
            assert_equal @new_default_options[key],
                         @attachment.instance_variable_get("@#{key}"),
                         key
          end
        end
      end
    end
  end

  context "An attachment with similarly named interpolations" do
    setup do
      rebuild_model :path => ":id.omg/:id-bbq/:idwhat/:id_partition.wtf"
      @dummy = Dummy.new
      @dummy.stubs(:id).returns(1024)
      @file = File.new(File.join(File.dirname(__FILE__),
                                 "fixtures",
                                 "5k.png"))
      @dummy.avatar = @file
    end

    should "make sure that they are interpolated correctly" do
      assert_equal "1024.omg/1024-bbq/1024what/000/001/024.wtf", @dummy.avatar.path
    end
  end

  context "An attachment" do
    setup do
      Paperclip::Attachment.default_options.merge!({
        :path => ":rails_root/tmp/:attachment/:class/:style/:id/:basename.:extension"
      })
      FileUtils.rm_rf("tmp")
      @instance = stub
      @instance.stubs(:id).returns(41)
      @instance.stubs(:class).returns(Dummy)
      @instance.stubs(:[]).with(:test_file_name).returns(nil)
      @instance.stubs(:[]).with(:test_content_type).returns(nil)
      @instance.stubs(:[]).with(:test_file_size).returns(nil)
      @attachment = Paperclip::Attachment.new(:test,
                                              @instance)
      @file = File.new(File.join(File.dirname(__FILE__),
                                 "fixtures",
                                 "5k.png"))
    end

    should "return its default_url when no file assigned" do
      assert @attachment.to_file.nil?
      assert_equal "/tests/original/missing.png", @attachment.url
      assert_equal "/tests/blah/missing.png", @attachment.url(:blah)
    end
    
    context "with a file assigned in the database" do
      setup do
        @instance.stubs(:[]).with(:test_file_name).returns("5k.png")
        @instance.stubs(:[]).with(:test_content_type).returns("image/png")
        @instance.stubs(:[]).with(:test_file_size).returns(12345)
      end

      should "return a correct url even if the file does not exist" do
        assert_nil @attachment.to_file
        assert_equal "/tests/41/blah/5k.png", @attachment.url(:blah)
      end

      should "return the proper path when filename has a single .'s" do
        assert_equal "./test/../tmp/tests/dummies/original/41/5k.png", @attachment.path
      end

      should "return the proper path when filename has multiple .'s" do
        @instance.stubs(:[]).with(:test_file_name).returns("5k.old.png")      
        assert_equal "./test/../tmp/tests/dummies/original/41/5k.old.png", @attachment.path
      end

      context "when expecting three styles" do
        setup do
          styles = {:styles => { :large  => ["400x400", :png],
                                 :medium => ["100x100", :gif],
                                 :small => ["32x32#", :jpg]}}
          @attachment = Paperclip::Attachment.new(:test,
                                                  @instance,
                                                  styles)
        end

        context "and assigned a file" do
          setup do
            @instance.expects(:[]=).with(:test_file_name,
                                         File.basename(@file.path))
            @instance.expects(:[]=).with(:test_content_type, "image/png")
            @instance.expects(:[]=).with(:test_file_size, @file.size)
            @instance.expects(:[]=).with(:test_file_name, nil)
            @instance.expects(:[]=).with(:test_content_type, nil)
            @instance.expects(:[]=).with(:test_file_size, nil)
            @attachment.assign(@file)
          end

          should "be dirty" do
            assert @attachment.dirty?
          end

          context "and saved" do
            setup do
              @attachment.save
            end

            should "return the real url" do
              assert @attachment.to_file
              assert_equal "/tests/41/original/5k.png", @attachment.url
              assert_equal "/tests/41/small/5k.jpg", @attachment.url(:small)
            end

            should "commit the files to disk" do
              [:large, :medium, :small].each do |style|
                io = @attachment.to_io(style)
                assert File.exists?(io)
                assert ! io.is_a?(::Tempfile)
              end
            end

            should "save the files as the right formats and sizes" do
              [[:large, 400, 61, "PNG"],
               [:medium, 100, 15, "GIF"],
               [:small, 32, 32, "JPEG"]].each do |style|
                cmd = "identify -format '%w %h %b %m' " + 
                      "#{@attachment.to_io(style.first).path}"
                out = `#{cmd}`
                width, height, size, format = out.split(" ")
                assert_equal style[1].to_s, width.to_s 
                assert_equal style[2].to_s, height.to_s
                assert_equal style[3].to_s, format.to_s
              end
            end

            should "still have its #file attribute not be nil" do
              assert ! @attachment.to_file.nil?
            end

            context "and deleted" do
              setup do
                @existing_names = @attachment.styles.keys.collect do |style|
                  @attachment.path(style)
                end
                @instance.expects(:[]=).with(:test_file_name, nil)
                @instance.expects(:[]=).with(:test_content_type, nil)
                @instance.expects(:[]=).with(:test_file_size, nil)
                @attachment.assign nil
                @attachment.save
              end

              should "delete the files" do
                @existing_names.each{|f| assert ! File.exists?(f) }
              end
            end
          end
        end
      end

    end

    context "when trying a nonexistant storage type" do
      setup do
        rebuild_model :storage => :not_here
      end

      should "not be able to find the module" do
        assert_raise(NameError){ Dummy.new.avatar }
      end
    end
  end
end
