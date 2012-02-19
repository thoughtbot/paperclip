# encoding: utf-8
require './test/helper'
require 'paperclip/attachment'

class Dummy; end

class AttachmentTest < Test::Unit::TestCase

  should "process :original style first" do
    file = File.new(File.join(File.dirname(__FILE__), "fixtures", "50x50.png"), 'rb')
    rebuild_class :styles => { :small => '100x>', :original => '42x42#' }
    dummy = Dummy.new
    dummy.avatar = file
    dummy.save

    # :small avatar should be 42px wide (processed original), not 50px (preprocessed original)
    assert_equal `identify -format "%w" "#{dummy.avatar.path(:small)}"`.strip, "42"

    file.close
  end

  should "handle a boolean second argument to #url" do
    mock_url_generator_builder = MockUrlGeneratorBuilder.new
    attachment = Paperclip::Attachment.new(:name, :instance, :url_generator => mock_url_generator_builder)

    attachment.url(:style_name, true)
    assert mock_url_generator_builder.has_generated_url_with_options?(:timestamp => true, :escape => true)

    attachment.url(:style_name, false)
    assert mock_url_generator_builder.has_generated_url_with_options?(:timestamp => false, :escape => true)
  end

  should "pass the style and options through to the URL generator on #url" do
    mock_url_generator_builder = MockUrlGeneratorBuilder.new
    attachment = Paperclip::Attachment.new(:name, :instance, :url_generator => mock_url_generator_builder)

    attachment.url(:style_name, :options => :values)
    assert mock_url_generator_builder.has_generated_url_with_options?(:options => :values)
  end

  should "pass default options through when #url is given one argument" do
    mock_url_generator_builder = MockUrlGeneratorBuilder.new
    attachment = Paperclip::Attachment.new(:name,
                                           :instance,
                                           :url_generator => mock_url_generator_builder,
                                           :use_timestamp => true)

    attachment.url(:style_name)
    assert mock_url_generator_builder.has_generated_url_with_options?(:escape => true, :timestamp => true)
  end

  should "pass default style and options through when #url is given no arguments" do
    mock_url_generator_builder = MockUrlGeneratorBuilder.new
    attachment = Paperclip::Attachment.new(:name,
                                           :instance,
                                           :default_style => 'default style',
                                           :url_generator => mock_url_generator_builder,
                                           :use_timestamp => true)

    attachment.url
    assert mock_url_generator_builder.has_generated_url_with_options?(:escape => true, :timestamp => true)
    assert mock_url_generator_builder.has_generated_url_with_style_name?('default style')
  end

  should "pass the option :timestamp => true if :use_timestamp is true and :timestamp is not passed" do
    mock_url_generator_builder = MockUrlGeneratorBuilder.new
    attachment = Paperclip::Attachment.new(:name,
                                           :instance,
                                           :url_generator => mock_url_generator_builder,
                                           :use_timestamp => true)

    attachment.url(:style_name)
    assert mock_url_generator_builder.has_generated_url_with_options?(:escape => true, :timestamp => true)
  end

  should "pass the option :timestamp => false if :use_timestamp is false and :timestamp is not passed" do
    mock_url_generator_builder = MockUrlGeneratorBuilder.new
    attachment = Paperclip::Attachment.new(:name,
                                           :instance,
                                           :url_generator => mock_url_generator_builder,
                                           :use_timestamp => false)

    attachment.url(:style_name)
    assert mock_url_generator_builder.has_generated_url_with_options?(:escape => true, :timestamp => false)
  end

  should "not change the :timestamp if :timestamp is passed" do
    mock_url_generator_builder = MockUrlGeneratorBuilder.new
    attachment = Paperclip::Attachment.new(:name,
                                           :instance,
                                           :url_generator => mock_url_generator_builder,
                                           :use_timestamp => false)

    attachment.url(:style_name, :timestamp => true)
    assert mock_url_generator_builder.has_generated_url_with_options?(:escape => true, :timestamp => true)
  end

  should "return the path based on the url by default" do
    @attachment = attachment :url => "/:class/:id/:basename"
    @model = @attachment.instance
    @model.id = 1234
    @model.avatar_file_name = "fake.jpg"
    assert_equal "#{Rails.root}/public/fake_models/1234/fake", @attachment.path
  end

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
                       @attachment.instance_variable_get("@options")[key],
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
                         @attachment.instance_variable_get("@options")[key],
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
                                 "5k.png"), 'rb')
      @dummy.avatar = @file
    end

    teardown { @file.close }

    should "make sure that they are interpolated correctly" do
      assert_equal "1024.omg/1024-bbq/1024what/000/001/024.wtf", @dummy.avatar.path
    end
  end

  context "An attachment with :timestamp interpolations" do
    setup do
      @file = StringIO.new("...")
      @zone = 'UTC'
      Time.stubs(:zone).returns(@zone)
      @zone_default = 'Eastern Time (US & Canada)'
      Time.stubs(:zone_default).returns(@zone_default)
    end

    context "using default time zone" do
      setup do
        rebuild_model :path => ":timestamp", :use_default_time_zone => true
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      should "return a time in the default zone" do
        assert_equal @dummy.avatar_updated_at.in_time_zone(@zone_default).to_s, @dummy.avatar.path
      end
    end

    context "using per-thread time zone" do
      setup do
        rebuild_model :path => ":timestamp", :use_default_time_zone => false
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      should "return a time in the per-thread zone" do
        assert_equal @dummy.avatar_updated_at.in_time_zone(@zone).to_s, @dummy.avatar.path
      end
    end
  end

  context "An attachment with :hash interpolations" do
    setup do
      @file = StringIO.new("...")
    end

    should "raise if no secret is provided" do
      @attachment = attachment :path => ":hash"
      @attachment.assign @file

      assert_raise ArgumentError do
        @attachment.path
      end
    end

    context "when secret is set" do
      setup do
        @attachment = attachment :path => ":hash", :hash_secret => "w00t"
        @attachment.stubs(:instance_read).with(:updated_at).returns(Time.at(1234567890))
        @attachment.stubs(:instance_read).with(:file_name).returns("bla.txt")
        @attachment.instance.id = 1234
        @attachment.assign @file
      end

      should "interpolate the hash data" do
        @attachment.expects(:interpolate).with(@attachment.options[:hash_data],anything).returns("interpolated_stuff")
        @attachment.hash_key
      end

      should "result in the correct interpolation" do
        assert_equal "fake_models/avatars/1234/original/1234567890", @attachment.send(:interpolate,@attachment.options[:hash_data])
      end

      should "result in a correct hash" do
        assert_equal "d22b617d1bf10016aa7d046d16427ae203f39fce", @attachment.path
      end

      should "generate a hash digest with the correct style" do
        OpenSSL::HMAC.expects(:hexdigest).with(anything, anything, "fake_models/avatars/1234/medium/1234567890")
        @attachment.path("medium")
      end
    end
  end

  context "An attachment with a :rails_env interpolation" do
    setup do
      @rails_env = "blah"
      @id = 1024
      rebuild_model :path => ":rails_env/:id.png"
      @dummy = Dummy.new
      @dummy.stubs(:id).returns(@id)
      @file = StringIO.new(".")
      @dummy.avatar = @file
      Rails.stubs(:env).returns(@rails_env)
    end

    should "return the proper path" do
      assert_equal "#{@rails_env}/#{@id}.png", @dummy.avatar.path
    end
  end

  context "An attachment with a default style and an extension interpolation" do
    setup do
      @attachment = attachment :path => ":basename.:extension",
                               :styles => { :default => ["100x100", :png] },
                               :default_style => :default
      @file = StringIO.new("...")
      @file.stubs(:original_filename).returns("file.jpg")
    end
    should "return the right extension for the path" do
      @attachment.assign(@file)
      assert_equal "file.png", @attachment.path
    end
  end

  context "An attachment with :convert_options" do
    setup do
      rebuild_model :styles => {
                      :thumb => "100x100",
                      :large => "400x400"
                    },
                    :convert_options => {
                      :all => "-do_stuff",
                      :thumb => "-thumbnailize"
                    }
      @dummy = Dummy.new
      @dummy.avatar
    end

    should "report the correct options when sent #extra_options_for(:thumb)" do
      assert_equal "-thumbnailize -do_stuff", @dummy.avatar.send(:extra_options_for, :thumb), @dummy.avatar.convert_options.inspect
    end

    should "report the correct options when sent #extra_options_for(:large)" do
      assert_equal "-do_stuff", @dummy.avatar.send(:extra_options_for, :large)
    end
  end

  context "An attachment with :source_file_options" do
    setup do
      rebuild_model :styles => {
                      :thumb => "100x100",
                      :large => "400x400"
                    },
                    :source_file_options => {
                      :all => "-density 400",
                      :thumb => "-depth 8"
                    }
      @dummy = Dummy.new
      @dummy.avatar
    end

    should "report the correct options when sent #extra_source_file_options_for(:thumb)" do
      assert_equal "-depth 8 -density 400", @dummy.avatar.send(:extra_source_file_options_for, :thumb), @dummy.avatar.source_file_options.inspect
    end

    should "report the correct options when sent #extra_source_file_options_for(:large)" do
      assert_equal "-density 400", @dummy.avatar.send(:extra_source_file_options_for, :large)
    end
  end

  context "An attachment with :only_process" do
    setup do
      rebuild_model :styles => {
                      :thumb => "100x100",
                      :large => "400x400"
                    },
                    :only_process => [:thumb]
      @file = StringIO.new("...")
      @attachment = Dummy.new.avatar
    end

    should "only process the provided style" do
      @attachment.expects(:post_process).with(:thumb)
      @attachment.expects(:post_process).with(:large).never
      @attachment.assign(@file)
    end
  end

  context "An attachment with :convert_options that is a proc" do
    setup do
      rebuild_model :styles => {
                      :thumb => "100x100",
                      :large => "400x400"
                    },
                    :convert_options => {
                      :all => lambda{|i| i.all },
                      :thumb => lambda{|i| i.thumb }
                    }
      Dummy.class_eval do
        def all;   "-all";   end
        def thumb; "-thumb"; end
      end
      @dummy = Dummy.new
      @dummy.avatar
    end

    should "report the correct options when sent #extra_options_for(:thumb)" do
      assert_equal "-thumb -all", @dummy.avatar.send(:extra_options_for, :thumb), @dummy.avatar.convert_options.inspect
    end

    should "report the correct options when sent #extra_options_for(:large)" do
      assert_equal "-all", @dummy.avatar.send(:extra_options_for, :large)
    end
  end

  context "An attachment with :path that is a proc" do
    setup do
      rebuild_model :path => lambda{ |attachment| "path/#{attachment.instance.other}.:extension" }

      @file = File.new(File.join(File.dirname(__FILE__),
                                 "fixtures",
                                 "5k.png"), 'rb')
      @dummyA = Dummy.new(:other => 'a')
      @dummyA.avatar = @file
      @dummyB = Dummy.new(:other => 'b')
      @dummyB.avatar = @file
    end

    teardown { @file.close }

    should "return correct path" do
      assert_equal "path/a.png", @dummyA.avatar.path
      assert_equal "path/b.png", @dummyB.avatar.path
    end
  end

  context "An attachment with :styles that is a proc" do
    setup do
      rebuild_model :styles => lambda{ |attachment| {:thumb => "50x50#", :large => "400x400"} }

      @attachment = Dummy.new.avatar
    end

    should "have the correct geometry" do
      assert_equal "50x50#", @attachment.styles[:thumb][:geometry]
    end
  end

  context "An attachment with conditional :styles that is a proc" do
    setup do
      rebuild_model :styles => lambda{ |attachment| attachment.instance.other == 'a' ? {:thumb => "50x50#"} : {:large => "400x400"} }

      @dummy = Dummy.new(:other => 'a')
    end

    should "have the correct styles for the assigned instance values" do
      assert_equal "50x50#", @dummy.avatar.styles[:thumb][:geometry]
      assert_nil @dummy.avatar.styles[:large]

      @dummy.other = 'b'

      assert_equal "400x400", @dummy.avatar.styles[:large][:geometry]
      assert_nil @dummy.avatar.styles[:thumb]
    end
  end

  geometry_specs = [
    [ lambda{|z| "50x50#" }, :png ],
    lambda{|z| "50x50#" },
    { :geometry => lambda{|z| "50x50#" } }
  ]
  geometry_specs.each do |geometry_spec|
    context "An attachment geometry like #{geometry_spec}" do
      setup do
        rebuild_model :styles => { :normal => geometry_spec }
        @attachment = Dummy.new.avatar
      end

      context "when assigned" do
        setup do
          @file = StringIO.new(".")
          @attachment.assign(@file)
        end

        should "have the correct geometry" do
          assert_equal "50x50#", @attachment.styles[:normal][:geometry]
        end
      end
    end
  end

  context "An attachment with both 'normal' and hash-style styles" do
    setup do
      rebuild_model :styles => {
                      :normal => ["50x50#", :png],
                      :hash => { :geometry => "50x50#", :format => :png }
                    }
      @dummy = Dummy.new
      @attachment = @dummy.avatar
    end

    [:processors, :whiny, :convert_options, :geometry, :format].each do |field|
      should "have the same #{field} field" do
        assert_equal @attachment.styles[:normal][field], @attachment.styles[:hash][field]
      end
    end
  end

  context "An attachment with :processors that is a proc" do
    setup do
      class Paperclip::Test < Paperclip::Processor; end
      @file = StringIO.new("...")
      Paperclip::Test.stubs(:make).returns(@file)

      rebuild_model :styles => { :normal => '' }, :processors => lambda { |a| [ :test ] }
      @attachment = Dummy.new.avatar
    end

    context "when assigned" do
      setup do
        @attachment.assign(StringIO.new("."))
      end

      should "have the correct processors" do
        assert_equal [ :test ], @attachment.styles[:normal][:processors]
      end
    end
  end

  context "An attachment with erroring processor" do
    setup do
      rebuild_model :processor => [:thumbnail], :styles => { :small => '' }, :whiny_thumbnails => true
      @dummy = Dummy.new
      Paperclip::Thumbnail.expects(:make).raises(Paperclip::PaperclipError, "cannot be processed.")
      @file = StringIO.new("...")
      @file.stubs(:to_tempfile).returns(@file)
      @dummy.avatar = @file
    end

    should "correctly forward processing error message to the instance" do
      @dummy.valid?
      assert_contains @dummy.errors.full_messages, "Avatar cannot be processed."
    end
  end

  context "An attachment with multiple processors" do
    setup do
      class Paperclip::Test < Paperclip::Processor; end
      @style_params = { :once => {:one => 1, :two => 2} }
      rebuild_model :processors => [:thumbnail, :test], :styles => @style_params
      @dummy = Dummy.new
      @file = StringIO.new("...")
      @file.stubs(:to_tempfile).returns(@file)
      Paperclip::Test.stubs(:make).returns(@file)
      Paperclip::Thumbnail.stubs(:make).returns(@file)
    end

    context "when assigned" do
      setup { @dummy.avatar = @file }

      before_should "call #make on all specified processors" do
        Paperclip::Thumbnail.expects(:make).with(any_parameters).returns(@file)
        Paperclip::Test.expects(:make).with(any_parameters).returns(@file)
      end

      before_should "call #make with the right parameters passed as second argument" do
        expected_params = @style_params[:once].merge({
          :processors => [:thumbnail, :test],
          :whiny => true,
          :convert_options => "",
          :source_file_options => ""
        })
        Paperclip::Thumbnail.expects(:make).with(anything, expected_params, anything).returns(@file)
      end

      before_should "call #make with attachment passed as third argument" do
        Paperclip::Test.expects(:make).with(anything, anything, @dummy.avatar).returns(@file)
      end
    end
  end

  should "include the filesystem module when loading the filesystem storage" do
    rebuild_model :storage => :filesystem
    @dummy = Dummy.new
    assert @dummy.avatar.is_a?(Paperclip::Storage::Filesystem)
  end

  should "include the filesystem module even if capitalization is wrong" do
    rebuild_model :storage => :FileSystem
    @dummy = Dummy.new
    assert @dummy.avatar.is_a?(Paperclip::Storage::Filesystem)

    rebuild_model :storage => :Filesystem
    @dummy = Dummy.new
    assert @dummy.avatar.is_a?(Paperclip::Storage::Filesystem)
  end

  should "convert underscored storage name to camelcase" do
    rebuild_model :storage => :not_here
    @dummy = Dummy.new
    exception = assert_raises(Paperclip::StorageMethodNotFound) do
      @dummy.avatar
    end
    assert exception.message.include?("NotHere")
  end

  should "raise an error if you try to include a storage module that doesn't exist" do
    rebuild_model :storage => :not_here
    @dummy = Dummy.new
    assert_raises(Paperclip::StorageMethodNotFound) do
      @dummy.avatar
    end
  end

  context "An attachment with styles but no processors defined" do
    setup do
      rebuild_model :processors => [], :styles => {:something => '1'}
      @dummy = Dummy.new
      @file = StringIO.new("...")
    end
    should "raise when assigned to" do
      assert_raises(RuntimeError){ @dummy.avatar = @file }
    end
  end

  context "An attachment without styles and with no processors defined" do
    setup do
      rebuild_model :processors => [], :styles => {}
      @dummy = Dummy.new
      @file = StringIO.new("...")
    end
    should "not raise when assigned to" do
      @dummy.avatar = @file
    end
  end

  context "Assigning an attachment with post_process hooks" do
    setup do
      rebuild_class :styles => { :something => "100x100#" }
      Dummy.class_eval do
        before_avatar_post_process :do_before_avatar
        after_avatar_post_process :do_after_avatar
        before_post_process :do_before_all
        after_post_process :do_after_all
        def do_before_avatar; end
        def do_after_avatar; end
        def do_before_all; end
        def do_after_all; end
      end
      @file  = StringIO.new(".")
      @file.stubs(:to_tempfile).returns(@file)
      @dummy = Dummy.new
      Paperclip::Thumbnail.stubs(:make).returns(@file)
      @attachment = @dummy.avatar
    end

    should "call the defined callbacks when assigned" do
      @dummy.expects(:do_before_avatar).with()
      @dummy.expects(:do_after_avatar).with()
      @dummy.expects(:do_before_all).with()
      @dummy.expects(:do_after_all).with()
      Paperclip::Thumbnail.expects(:make).returns(@file)
      @dummy.avatar = @file
    end

    should "not cancel the processing if a before_post_process returns nil" do
      @dummy.expects(:do_before_avatar).with().returns(nil)
      @dummy.expects(:do_after_avatar).with()
      @dummy.expects(:do_before_all).with().returns(nil)
      @dummy.expects(:do_after_all).with()
      Paperclip::Thumbnail.expects(:make).returns(@file)
      @dummy.avatar = @file
    end

    should "cancel the processing if a before_post_process returns false" do
      @dummy.expects(:do_before_avatar).never
      @dummy.expects(:do_after_avatar).never
      @dummy.expects(:do_before_all).with().returns(false)
      @dummy.expects(:do_after_all)
      Paperclip::Thumbnail.expects(:make).never
      @dummy.avatar = @file
    end

    should "cancel the processing if a before_avatar_post_process returns false" do
      @dummy.expects(:do_before_avatar).with().returns(false)
      @dummy.expects(:do_after_avatar)
      @dummy.expects(:do_before_all).with().returns(true)
      @dummy.expects(:do_after_all)
      Paperclip::Thumbnail.expects(:make).never
      @dummy.avatar = @file
    end
  end

  context "Assigning an attachment" do
    setup do
      rebuild_model :styles => { :something => "100x100#" }
      @file = StringIO.new(".")
      @file.stubs(:original_filename).returns("5k.png\n\n")
      @file.stubs(:content_type).returns("image/png\n\n")
      @file.stubs(:to_tempfile).returns(@file)
      @dummy = Dummy.new
      Paperclip::Thumbnail.expects(:make).returns(@file)
      @attachment = @dummy.avatar
      @dummy.avatar = @file
    end

    should "strip whitespace from original_filename field" do
      assert_equal "5k.png", @dummy.avatar.original_filename
    end

    should "strip whitespace from content_type field" do
      assert_equal "image/png", @dummy.avatar.instance.avatar_content_type
    end
  end

  context "Attachment with strange letters" do
    setup do
      rebuild_model

      @not_file = mock("not_file")
      @tempfile = mock("tempfile")
      @not_file.stubs(:nil?).returns(false)
      @not_file.expects(:size).returns(10)
      @tempfile.expects(:size).returns(10)
      @not_file.expects(:original_filename).returns("sheep_say_bæ.png\r\n")
      @not_file.expects(:content_type).returns("image/png\r\n")

      @dummy = Dummy.new
      @attachment = @dummy.avatar
      @attachment.expects(:valid_assignment?).with(@not_file).returns(true)
      @attachment.expects(:queue_existing_for_delete)
      @attachment.expects(:post_process)
      @attachment.expects(:to_tempfile).returns(@tempfile)
      @attachment.expects(:generate_fingerprint).with(@tempfile).returns("12345")
      @attachment.expects(:generate_fingerprint).with(@not_file).returns("12345")
      @dummy.avatar = @not_file
    end

    should "not remove strange letters" do
      assert_equal "sheep_say_bæ.png", @dummy.avatar.original_filename
    end
  end

  context "Attachment with reserved filename" do
    setup do
      rebuild_model
      @file = StringIO.new(".")
    end

    context "with default configuration" do
      "&$+,/:;=?@<>[]{}|\^~%# ".split(//).each do |character|
        context "with character #{character}" do
          setup do
            @file.stubs(:original_filename).returns("file#{character}name.png")
            @dummy = Dummy.new
            @dummy.avatar = @file
          end

          should "convert special character into underscore" do
            assert_equal "file_name.png", @dummy.avatar.original_filename
          end
        end
      end
    end

    context "with specified regexp replacement" do
      setup do
        @old_defaults = Paperclip::Attachment.default_options.dup
        Paperclip::Attachment.default_options.merge! :restricted_characters => /o/

        @file.stubs(:original_filename).returns("goood.png")
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      teardown do
        Paperclip::Attachment.default_options.merge! @old_defaults
      end

      should "match and convert that character" do
        assert_equal "g___d.png", @dummy.avatar.original_filename
      end
    end
  end

  context "Attachment with uppercase extension and a default style" do
    setup do
      @old_defaults = Paperclip::Attachment.default_options.dup
      Paperclip::Attachment.default_options.merge!({
        :path => ":rails_root/tmp/:attachment/:class/:style/:id/:basename.:extension"
      })
      FileUtils.rm_rf("tmp")
      rebuild_model
      @instance = Dummy.new
      @instance.stubs(:id).returns 123

      @file = File.new(File.join(File.dirname(__FILE__), "fixtures", "uppercase.PNG"), 'rb')

      styles = {:styles => { :large  => ["400x400", :jpg],
                             :medium => ["100x100", :jpg],
                             :small => ["32x32#", :jpg]},
                :default_style => :small}
      @attachment = Paperclip::Attachment.new(:avatar,
                                              @instance,
                                              styles)
      now = Time.now
      Time.stubs(:now).returns(now)
      @attachment.assign(@file)
      @attachment.save
    end

    teardown do
      @file.close
      Paperclip::Attachment.default_options.merge!(@old_defaults)
    end

    should "should have matching to_s and url methods" do
      file = @attachment.to_file
      assert file
      assert_match @attachment.to_s, @attachment.url
      assert_match @attachment.to_s(:small), @attachment.url(:small)
      file.close
    end
  end

  context "An attachment" do
    setup do
      @old_defaults = Paperclip::Attachment.default_options.dup
      Paperclip::Attachment.default_options.merge!({
        :path => ":rails_root/tmp/:attachment/:class/:style/:id/:basename.:extension"
      })
      FileUtils.rm_rf("tmp")
      rebuild_model
      @instance = Dummy.new
      @instance.stubs(:id).returns 123
      @attachment = Paperclip::Attachment.new(:avatar, @instance)
      @file = File.new(File.join(File.dirname(__FILE__), "fixtures", "5k.png"), 'rb')
    end

    teardown do
      @file.close
      Paperclip::Attachment.default_options.merge!(@old_defaults)
    end

    should "raise if there are not the correct columns when you try to assign" do
      @other_attachment = Paperclip::Attachment.new(:not_here, @instance)
      assert_raises(Paperclip::PaperclipError) do
        @other_attachment.assign(@file)
      end
    end

    should "return nil as path when no file assigned" do
      assert @attachment.to_file.nil?
      assert_equal nil, @attachment.path
      assert_equal nil, @attachment.path(:blah)
    end

    context "with a file assigned but not saved yet" do
      should "clear out any attached files" do
        @attachment.assign(@file)
        assert !@attachment.queued_for_write.blank?
        @attachment.clear
        assert @attachment.queued_for_write.blank?
      end
    end

    context "with a file assigned in the database" do
      setup do
        @attachment.stubs(:instance_read).with(:file_name).returns("5k.png")
        @attachment.stubs(:instance_read).with(:content_type).returns("image/png")
        @attachment.stubs(:instance_read).with(:file_size).returns(12345)
        dtnow = DateTime.now
        @now = Time.now
        Time.stubs(:now).returns(@now)
        @attachment.stubs(:instance_read).with(:updated_at).returns(dtnow)
      end

      should "return the proper path when filename has a single .'s" do
        assert_equal File.expand_path("./test/../tmp/avatars/dummies/original/#{@instance.id}/5k.png"), File.expand_path(@attachment.path)
      end

      should "return the proper path when filename has multiple .'s" do
        @attachment.stubs(:instance_read).with(:file_name).returns("5k.old.png")
        assert_equal File.expand_path("./test/../tmp/avatars/dummies/original/#{@instance.id}/5k.old.png"), File.expand_path(@attachment.path)
      end

      context "when expecting three styles" do
        setup do
          styles = {:styles => { :large  => ["400x400", :png],
                                 :medium => ["100x100", :gif],
                                 :small => ["32x32#", :jpg]}}
          @attachment = Paperclip::Attachment.new(:avatar,
                                                  @instance,
                                                  styles)
        end

        context "and assigned a file" do
          setup do
            now = Time.now
            Time.stubs(:now).returns(now)
            @attachment.assign(@file)
          end

          should "be dirty" do
            assert @attachment.dirty?
          end

          should "set uploaded_file for access beyond the paperclip lifecycle" do
            assert_equal @file, @attachment.uploaded_file
          end

          context "and saved" do
            setup do
              @attachment.save
            end

            should "commit the files to disk" do
              [:large, :medium, :small].each do |style|
                io = @attachment.to_file(style)
                # p "in commit to disk test, io is #{io.inspect} and @instance.id is #{@instance.id}"
                assert File.exists?(io.path)
                assert ! io.is_a?(::Tempfile)
                io.close
              end
            end

            should "save the files as the right formats and sizes" do
              [[:large, 400, 61, "PNG"],
               [:medium, 100, 15, "GIF"],
               [:small, 32, 32, "JPEG"]].each do |style|
                cmd = %Q[identify -format "%w %h %b %m" "#{@attachment.path(style.first)}"]
                out = `#{cmd}`
                width, height, size, format = out.split(" ")
                assert_equal style[1].to_s, width.to_s
                assert_equal style[2].to_s, height.to_s
                assert_equal style[3].to_s, format.to_s
              end
            end

            should "still have its #file attribute not be nil" do
              assert ! (file = @attachment.to_file).nil?
              file.close
            end

            context "and trying to delete" do
              setup do
                @existing_names = @attachment.styles.keys.collect do |style|
                  @attachment.path(style)
                end
              end

              should "delete the files after assigning nil" do
                @attachment.expects(:instance_write).with(:file_name, nil)
                @attachment.expects(:instance_write).with(:content_type, nil)
                @attachment.expects(:instance_write).with(:file_size, nil)
                @attachment.expects(:instance_write).with(:fingerprint, nil)
                @attachment.expects(:instance_write).with(:updated_at, nil)
                @attachment.assign nil
                @attachment.save
                @existing_names.each{|f| assert ! File.exists?(f) }
              end

              should "delete the files when you call #clear and #save" do
                @attachment.expects(:instance_write).with(:file_name, nil)
                @attachment.expects(:instance_write).with(:content_type, nil)
                @attachment.expects(:instance_write).with(:file_size, nil)
                @attachment.expects(:instance_write).with(:fingerprint, nil)
                @attachment.expects(:instance_write).with(:updated_at, nil)
                @attachment.clear
                @attachment.save
                @existing_names.each{|f| assert ! File.exists?(f) }
              end

              should "delete the files when you call #delete" do
                @attachment.expects(:instance_write).with(:file_name, nil)
                @attachment.expects(:instance_write).with(:content_type, nil)
                @attachment.expects(:instance_write).with(:file_size, nil)
                @attachment.expects(:instance_write).with(:fingerprint, nil)
                @attachment.expects(:instance_write).with(:updated_at, nil)
                @attachment.destroy
                @existing_names.each{|f| assert ! File.exists?(f) }
              end

              context "when keeping old files" do
                setup do
                  @attachment.options[:keep_old_files] = true
                end

                should "keep the files after assigning nil" do
                  @attachment.expects(:instance_write).with(:file_name, nil)
                  @attachment.expects(:instance_write).with(:content_type, nil)
                  @attachment.expects(:instance_write).with(:file_size, nil)
                  @attachment.expects(:instance_write).with(:fingerprint, nil)
                  @attachment.expects(:instance_write).with(:updated_at, nil)
                  @attachment.assign nil
                  @attachment.save
                  @existing_names.each{|f| assert File.exists?(f) }
                end

                should "keep the files when you call #clear and #save" do
                  @attachment.expects(:instance_write).with(:file_name, nil)
                  @attachment.expects(:instance_write).with(:content_type, nil)
                  @attachment.expects(:instance_write).with(:file_size, nil)
                  @attachment.expects(:instance_write).with(:fingerprint, nil)
                  @attachment.expects(:instance_write).with(:updated_at, nil)
                  @attachment.clear
                  @attachment.save
                  @existing_names.each{|f| assert File.exists?(f) }
                end

                should "keep the files when you call #delete" do
                  @attachment.expects(:instance_write).with(:file_name, nil)
                  @attachment.expects(:instance_write).with(:content_type, nil)
                  @attachment.expects(:instance_write).with(:file_size, nil)
                  @attachment.expects(:instance_write).with(:fingerprint, nil)
                  @attachment.expects(:instance_write).with(:updated_at, nil)
                  @attachment.destroy
                  @existing_names.each{|f| assert File.exists?(f) }
                end
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
        assert_raise(Paperclip::StorageMethodNotFound){ Dummy.new.avatar }
      end
    end
  end

  context "An attachment with only a avatar_file_name column" do
    setup do
      ActiveRecord::Base.connection.create_table :dummies, :force => true do |table|
        table.column :avatar_file_name, :string
      end
      rebuild_class
      @dummy = Dummy.new
      @file = File.new(File.join(File.dirname(__FILE__), "fixtures", "5k.png"), 'rb')
    end

    teardown { @file.close }

    should "not error when assigned an attachment" do
      assert_nothing_raised { @dummy.avatar = @file }
    end

    should "return the time when sent #avatar_updated_at" do
      now = Time.now
      Time.stubs(:now).returns(now)
      @dummy.avatar = @file
      assert_equal now.to_i, @dummy.avatar.updated_at.to_i
    end

    should "return nil when reloaded and sent #avatar_updated_at" do
      @dummy.save
      @dummy.reload
      assert_nil @dummy.avatar.updated_at
    end

    should "return the right value when sent #avatar_file_size" do
      @dummy.avatar = @file
      assert_equal @file.size, @dummy.avatar.size
    end

    context "and avatar_updated_at column" do
      setup do
        ActiveRecord::Base.connection.add_column :dummies, :avatar_updated_at, :timestamp
        rebuild_class
        @dummy = Dummy.new
      end

      should "not error when assigned an attachment" do
        assert_nothing_raised { @dummy.avatar = @file }
      end

      should "return the right value when sent #avatar_updated_at" do
        now = Time.now
        Time.stubs(:now).returns(now)
        @dummy.avatar = @file
        assert_equal now.to_i, @dummy.avatar.updated_at
      end
    end
    
    should "not calculate fingerprint after save" do
      @dummy.avatar = @file
      @dummy.save
      assert_nil @dummy.avatar.fingerprint
    end
    
    should "not calculate fingerprint before saving" do
      @dummy.avatar = @file
      assert_nil @dummy.avatar.fingerprint
    end
    
    context "and avatar_content_type column" do
      setup do
        ActiveRecord::Base.connection.add_column :dummies, :avatar_content_type, :string
        rebuild_class
        @dummy = Dummy.new
      end

      should "not error when assigned an attachment" do
        assert_nothing_raised { @dummy.avatar = @file }
      end

      should "return the right value when sent #avatar_content_type" do
        @dummy.avatar = @file
        assert_equal "image/png", @dummy.avatar.content_type
      end
    end

    context "and avatar_file_size column" do
      setup do
        ActiveRecord::Base.connection.add_column :dummies, :avatar_file_size, :integer
        rebuild_class
        @dummy = Dummy.new
      end

      should "not error when assigned an attachment" do
        assert_nothing_raised { @dummy.avatar = @file }
      end

      should "return the right value when sent #avatar_file_size" do
        @dummy.avatar = @file
        assert_equal @file.size, @dummy.avatar.size
      end

      should "return the right value when saved, reloaded, and sent #avatar_file_size" do
        @dummy.avatar = @file
        @dummy.save
        @dummy = Dummy.find(@dummy.id)
        assert_equal @file.size, @dummy.avatar.size
      end
    end

    context "and avatar_fingerprint column" do
      setup do
        ActiveRecord::Base.connection.add_column :dummies, :avatar_fingerprint, :string
        rebuild_class
        @dummy = Dummy.new
      end

      should "not error when assigned an attachment" do
        assert_nothing_raised { @dummy.avatar = @file }
      end

      should "return the right value when sent #avatar_fingerprint" do
        @dummy.avatar = @file
        assert_equal 'aec488126c3b33c08a10c3fa303acf27', @dummy.avatar_fingerprint
      end

      should "return the right value when saved, reloaded, and sent #avatar_fingerprint" do
        @dummy.avatar = @file
        @dummy.save
        @dummy = Dummy.find(@dummy.id)
        assert_equal 'aec488126c3b33c08a10c3fa303acf27', @dummy.avatar_fingerprint
      end
    end
  end

  context "an attachment with delete_file option set to false" do
    setup do
      rebuild_model :preserve_files => true
      @dummy = Dummy.new
      @file = File.new(File.join(File.dirname(__FILE__), "fixtures", "5k.png"), 'rb')
      @dummy.avatar = @file
      @dummy.save!
      @attachment = @dummy.avatar
      @path = @attachment.path
    end

    should "not delete the files from storage when attachment is destroyed" do
      @attachment.destroy
      assert File.exists?(@path)
    end

    should "not delete the file when model is destroyed" do
      @dummy.destroy
      assert File.exists?(@path)
    end
  end

  context "An attached file" do
    setup do
      rebuild_model
      @dummy = Dummy.new
      @file = File.new(File.join(File.dirname(__FILE__), "fixtures", "5k.png"), 'rb')
      @dummy.avatar = @file
      @dummy.save!
      @attachment = @dummy.avatar
      @path = @attachment.path
    end

    should "not be deleted when the model fails to destroy" do
      @dummy.stubs(:destroy).raises(Exception)

      assert_raise Exception do
        @dummy.destroy
      end

      assert File.exists?(@path), "#{@path} does not exist."
    end

    should "be deleted when the model is destroyed" do
      @dummy.destroy
      assert ! File.exists?(@path), "#{@path} does not exist."
    end
  end

end
