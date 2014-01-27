# encoding: utf-8
require './test/helper'
require 'paperclip/attachment'

class Dummy; end

class AttachmentTest < Test::Unit::TestCase

  context "presence" do
    setup do
      rebuild_class
      @dummy = Dummy.new
    end

    context "when file not set" do
      should "not be present" do
        assert @dummy.avatar.blank?
        refute @dummy.avatar.present?
      end
    end

    context "when file set" do
      setup { @dummy.avatar = File.new(fixture_file("50x50.png"), "rb") }

      should "be present" do
        refute @dummy.avatar.blank?
        assert @dummy.avatar.present?
      end
    end
  end

  should "process :original style first" do
    file = File.new(fixture_file("50x50.png"), 'rb')
    rebuild_class :styles => { :small => '100x>', :original => '42x42#' }
    dummy = Dummy.new
    dummy.avatar = file
    dummy.save

    # :small avatar should be 42px wide (processed original), not 50px (preprocessed original)
    assert_equal `identify -format "%w" "#{dummy.avatar.path(:small)}"`.strip, "42"

    file.close
  end

  should "not delete styles that don't get reprocessed" do
    file = File.new(fixture_file("50x50.png"), 'rb')
    rebuild_class :styles => { :small => '100x>',
                               :large => '500x>',
                               :original => '42x42#' }
    dummy = Dummy.new
    dummy.avatar = file
    dummy.save

    assert_file_exists(dummy.avatar.path(:small))
    assert_file_exists(dummy.avatar.path(:large))
    assert_file_exists(dummy.avatar.path(:original))

    dummy.avatar.reprocess!(:small)

    assert_file_exists(dummy.avatar.path(:small))
    assert_file_exists(dummy.avatar.path(:large))
    assert_file_exists(dummy.avatar.path(:original))
  end

  context "having a not empty hash as a default option" do
    setup do
      @old_default_options = Paperclip::Attachment.default_options.dup
      @new_default_options = { :convert_options => { :all => "-background white" } }
      Paperclip::Attachment.default_options.merge!(@new_default_options)
    end

    teardown do
      Paperclip::Attachment.default_options.merge!(@old_default_options)
    end

    should "deep merge when it is overridden" do
      new_options = { :convert_options => { :thumb => "-thumbnailize" } }
      attachment = Paperclip::Attachment.new(:name, :instance, new_options)

      assert_equal Paperclip::Attachment.default_options.deep_merge(new_options),
                   attachment.instance_variable_get("@options")
    end
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

  should "render JSON as default style" do
    mock_url_generator_builder = MockUrlGeneratorBuilder.new
    attachment = Paperclip::Attachment.new(:name,
                                           :instance,
                                           :default_style => 'default style',
                                           :url_generator => mock_url_generator_builder)

    attachment.as_json
    assert mock_url_generator_builder.has_generated_url_with_style_name?('default style')
  end

  should "pass the option :escape => true if :escape_url is true and :escape is not passed" do
    mock_url_generator_builder = MockUrlGeneratorBuilder.new
    attachment = Paperclip::Attachment.new(:name,
                                           :instance,
                                           :url_generator => mock_url_generator_builder,
                                           :escape_url => true)

    attachment.url(:style_name)
    assert mock_url_generator_builder.has_generated_url_with_options?(:escape => true)
  end

  should "pass the option :escape => false if :escape_url is false and :escape is not passed" do
    mock_url_generator_builder = MockUrlGeneratorBuilder.new
    attachment = Paperclip::Attachment.new(:name,
                                           :instance,
                                           :url_generator => mock_url_generator_builder,
                                           :escape_url => false)

    attachment.url(:style_name)
    assert mock_url_generator_builder.has_generated_url_with_options?(:escape => false)
  end

  should "return the path based on the url by default" do
    @attachment = attachment :url => "/:class/:id/:basename"
    @model = @attachment.instance
    @model.id = 1234
    @model.avatar_file_name = "fake.jpg"
    assert_equal "#{Rails.root}/public/fake_models/1234/fake", @attachment.path
  end

  should "default to a path that scales" do
    avatar_attachment = attachment
    model = avatar_attachment.instance
    model.id = 1234
    model.avatar_file_name = "fake.jpg"
    expected_path = "#{Rails.root}/public/system/fake_models/avatars/000/001/234/original/fake.jpg"
    assert_equal expected_path, avatar_attachment.path
  end

  should "render JSON as the URL to the attachment" do
    avatar_attachment = attachment
    model = avatar_attachment.instance
    model.id = 1234
    model.avatar_file_name = "fake.jpg"
    assert_equal attachment.url, attachment.as_json
  end

  should "render JSON from the model when requested by :methods" do
    rebuild_model
    dummy = Dummy.new
    dummy.id = 1234
    dummy.avatar_file_name = "fake.jpg"
    expected_string = '{"avatar":"/system/dummies/avatars/000/001/234/original/fake.jpg"}'
    if ActiveRecord::Base.include_root_in_json # This is true by default in Rails 3, and false in 4
      expected_string = %({"dummy":#{expected_string}})
    end
    # active_model pre-3.2 checks only by calling any? on it, thus it doesn't work if it is empty
    assert_equal expected_string, dummy.to_json(:only => [:dummy_key_for_old_active_model], :methods => [:avatar])
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
      @file = File.new(fixture_file("5k.png"), 'rb')
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
      @file = StringIO.new("...\n")
    end

    should "raise if no secret is provided" do
      rebuild_model :path => ":hash"
      @attachment = Dummy.new.avatar
      @attachment.assign @file

      assert_raise ArgumentError do
        @attachment.path
      end
    end

    context "when secret is set" do
      setup do
        rebuild_model :path => ":hash",
          :hash_secret => "w00t",
          :hash_data => ":class/:attachment/:style/:filename"
        @attachment = Dummy.new.avatar
        @attachment.assign @file
      end

      should "result in the correct interpolation" do
        assert_equal "dummies/avatars/original/data.txt",
          @attachment.send(:interpolate, @attachment.options[:hash_data])
        assert_equal "dummies/avatars/thumb/data.txt",
          @attachment.send(:interpolate, @attachment.options[:hash_data], :thumb)
      end

      should "result in a correct hash" do
        assert_equal "e1079a5c34ddbd197ebd0280d07952d98a57fb30", @attachment.path
        assert_equal "d740189bd3e49ef226fab84c8d45f7ae4126d043", @attachment.path(:thumb)
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
      rebuild_model :path => ":basename.:extension",
        :styles => { :default => ["100x100", :jpg] },
        :default_style => :default
      @attachment = Dummy.new.avatar
      @file = File.open(fixture_file("5k.png"))
      @file.stubs(:original_filename).returns("file.png")
    end
    should "return the right extension for the path" do
      @attachment.assign(@file)
      assert_equal "file.jpg", @attachment.path
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

  context "An attachment with :only_process that is a proc" do
    setup do
      rebuild_model :styles => {
                      :thumb => "100x100",
                      :large => "400x400"
                    },
                    :only_process => lambda { |attachment| [:thumb] }

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

      @file = File.new(fixture_file("5k.png"), 'rb')
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
      Paperclip::Thumbnail.expects(:make).raises(Paperclip::Error, "cannot be processed.")
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
      @file.stubs(:close)
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
    exception = assert_raises(Paperclip::Errors::StorageMethodNotFound) do
      @dummy.avatar
    end
    assert exception.message.include?("NotHere")
  end

  should "raise an error if you try to include a storage module that doesn't exist" do
    rebuild_model :storage => :not_here
    @dummy = Dummy.new
    assert_raises(Paperclip::Errors::StorageMethodNotFound) do
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
      @file = File.new(fixture_file("5k.png"), "rb")
      @dummy = Dummy.new
      @dummy.avatar = @file
    end

    should "strip whitespace from original_filename field" do
      assert_equal "5k.png", @dummy.avatar.original_filename
    end

    should "strip whitespace from content_type field" do
      assert_equal "image/png", @dummy.avatar.instance.avatar_content_type
    end
  end

  context "Assigning an attachment" do
    setup do
      rebuild_model :styles => { :something => "100x100#" }
      @file = File.new(fixture_file("5k.png"), "rb")
      @dummy = Dummy.new
      @dummy.avatar = @file
    end

    should "make sure the content_type is a string" do
      assert_equal "image/png", @dummy.avatar.instance.avatar_content_type
    end
  end

  context "Attachment with strange letters" do
    setup do
      rebuild_model
      @file = File.new(fixture_file("5k.png"), "rb")
      @file.stubs(:original_filename).returns("sheep_say_bæ.png")
      @dummy = Dummy.new
      @dummy.avatar = @file
    end

    should "not remove strange letters" do
      assert_equal "sheep_say_bæ.png", @dummy.avatar.original_filename
    end
  end

  context "Attachment with reserved filename" do
    setup do
      rebuild_model
      @file = Tempfile.new(["filename","png"])
    end

    teardown do
      @file.unlink
    end

    context "with default configuration" do
      "&$+,/:;=?@<>[]{}|\^~%# ".split(//).each do |character|
        context "with character #{character}" do

          context "at beginning of filename" do
            setup do
              @file.stubs(:original_filename).returns("#{character}filename.png")
              @dummy = Dummy.new
              @dummy.avatar = @file
            end

            should "convert special character into underscore" do
              assert_equal "_filename.png", @dummy.avatar.original_filename
            end
          end

          context "at end of filename" do
            setup do
              @file.stubs(:original_filename).returns("filename.png#{character}")
              @dummy = Dummy.new
              @dummy.avatar = @file
            end

            should "convert special character into underscore" do
              assert_equal "filename.png_", @dummy.avatar.original_filename
            end
          end

          context "in the middle of filename" do
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
    end

    context "with specified regexp replacement" do
      setup do
        @old_defaults = Paperclip::Attachment.default_options.dup
      end

      teardown do
        Paperclip::Attachment.default_options.merge! @old_defaults
      end

      context 'as another regexp' do
        setup do
          Paperclip::Attachment.default_options.merge! :restricted_characters => /o/

          @file.stubs(:original_filename).returns("goood.png")
          @dummy = Dummy.new
          @dummy.avatar = @file
        end

        should "match and convert that character" do
          assert_equal "g___d.png", @dummy.avatar.original_filename
        end
      end

      context 'as nil' do
        setup do
          Paperclip::Attachment.default_options.merge! :restricted_characters => nil

          @file.stubs(:original_filename).returns("goood.png")
          @dummy = Dummy.new
          @dummy.avatar = @file
        end

        should "ignore and return the original file name" do
          assert_equal "goood.png", @dummy.avatar.original_filename
        end
      end
    end

    context 'with specified cleaner' do
      setup do
        @old_defaults = Paperclip::Attachment.default_options.dup
      end

      teardown do
        Paperclip::Attachment.default_options.merge! @old_defaults
      end

      should 'call the given proc and take the result as cleaned filename' do
        Paperclip::Attachment.default_options[:filename_cleaner] = lambda do |str|
          "from_proc_#{str}"
        end

        @file.stubs(:original_filename).returns("goood.png")
        @dummy = Dummy.new
        @dummy.avatar = @file
        assert_equal "from_proc_goood.png", @dummy.avatar.original_filename
      end

      should 'call the given object and take the result as the cleaned filename' do
        class MyCleaner
          def call(filename)
            "foo"
          end
        end
        Paperclip::Attachment.default_options[:filename_cleaner] = MyCleaner.new

        @file.stubs(:original_filename).returns("goood.png")
        @dummy = Dummy.new
        @dummy.avatar = @file
        assert_equal "foo", @dummy.avatar.original_filename
      end
    end
  end

  context "Attachment with uppercase extension and a default style" do
    setup do
      @old_defaults = Paperclip::Attachment.default_options.dup
      Paperclip::Attachment.default_options.merge!({
        :path => ":rails_root/:attachment/:class/:style/:id/:basename.:extension"
      })
      FileUtils.rm_rf("tmp")
      rebuild_model :styles => { :large  => ["400x400", :jpg],
                             :medium => ["100x100", :jpg],
                             :small => ["32x32#", :jpg]},
                    :default_style => :small
      @instance = Dummy.new
      @instance.stubs(:id).returns 123
      @file = File.new(fixture_file("uppercase.PNG"), 'rb')

      @attachment = @instance.avatar

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
      assert_match @attachment.to_s, @attachment.url
      assert_match @attachment.to_s(:small), @attachment.url(:small)
    end

    should "have matching expiring_url and url methods when using the filesystem storage" do
      assert_match @attachment.expiring_url, @attachment.url
    end
  end

  context "An attachment" do
    setup do
      @old_defaults = Paperclip::Attachment.default_options.dup
      Paperclip::Attachment.default_options.merge!({
        :path => ":rails_root/:attachment/:class/:style/:id/:basename.:extension"
      })
      FileUtils.rm_rf("tmp")
      rebuild_model
      @instance = Dummy.new
      @instance.stubs(:id).returns 123
      # @attachment = Paperclip::Attachment.new(:avatar, @instance)
      @attachment = @instance.avatar
      @file = File.new(fixture_file("5k.png"), 'rb')
    end

    teardown do
      @file.close
      Paperclip::Attachment.default_options.merge!(@old_defaults)
    end

    should "raise if there are not the correct columns when you try to assign" do
      @other_attachment = Paperclip::Attachment.new(:not_here, @instance)
      assert_raises(Paperclip::Error) do
        @other_attachment.assign(@file)
      end
    end

    should 'clear out the previous assignment when assigned nil' do
      @attachment.assign(@file)
      @attachment.queued_for_write[:original]
      @attachment.assign(nil)
      assert_nil @attachment.queued_for_write[:original]
    end

    should 'not do anything when it is assigned an empty string' do
      @attachment.assign(@file)
      original_file = @attachment.queued_for_write[:original]
      @attachment.assign("")
      assert_equal original_file, @attachment.queued_for_write[:original]
    end

    should "return nil as path when no file assigned" do
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
        assert_equal File.expand_path("tmp/avatars/dummies/original/#{@instance.id}/5k.png"), File.expand_path(@attachment.path)
      end

      should "return the proper path when filename has multiple .'s" do
        @attachment.stubs(:instance_read).with(:file_name).returns("5k.old.png")
        assert_equal File.expand_path("tmp/avatars/dummies/original/#{@instance.id}/5k.old.png"), File.expand_path(@attachment.path)
      end

      context "when expecting three styles" do
        setup do
          rebuild_class :styles => {
            :large  => ["400x400", :png],
            :medium => ["100x100", :gif],
            :small => ["32x32#", :jpg]
          }
          @instance = Dummy.new
          @instance.stubs(:id).returns 123
          @file = File.new(fixture_file("5k.png"), 'rb')
          @attachment = @instance.avatar
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

          context "and saved" do
            setup do
              @attachment.save
            end

            should "commit the files to disk" do
              [:large, :medium, :small].each do |style|
                assert_file_exists(@attachment.path(style))
              end
            end

            should "save the files as the right formats and sizes" do
              [[:large, 400, 61, "PNG"],
               [:medium, 100, 15, "GIF"],
               [:small, 32, 32, "JPEG"]].each do |style|
                cmd = %Q[identify -format "%w %h %b %m" "#{@attachment.path(style.first)}"]
                out = `#{cmd}`
                width, height, _size, format = out.split(" ")
                assert_equal style[1].to_s, width.to_s
                assert_equal style[2].to_s, height.to_s
                assert_equal style[3].to_s, format.to_s
              end
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
                @existing_names.each{|f| assert_file_not_exists(f) }
              end

              should "delete the files when you call #clear and #save" do
                @attachment.expects(:instance_write).with(:file_name, nil)
                @attachment.expects(:instance_write).with(:content_type, nil)
                @attachment.expects(:instance_write).with(:file_size, nil)
                @attachment.expects(:instance_write).with(:fingerprint, nil)
                @attachment.expects(:instance_write).with(:updated_at, nil)
                @attachment.clear
                @attachment.save
                @existing_names.each{|f| assert_file_not_exists(f) }
              end

              should "delete the files when you call #delete" do
                @attachment.expects(:instance_write).with(:file_name, nil)
                @attachment.expects(:instance_write).with(:content_type, nil)
                @attachment.expects(:instance_write).with(:file_size, nil)
                @attachment.expects(:instance_write).with(:fingerprint, nil)
                @attachment.expects(:instance_write).with(:updated_at, nil)
                @attachment.destroy
                @existing_names.each{|f| assert_file_not_exists(f) }
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
                  @existing_names.each{|f| assert_file_exists(f) }
                end

                should "keep the files when you call #clear and #save" do
                  @attachment.expects(:instance_write).with(:file_name, nil)
                  @attachment.expects(:instance_write).with(:content_type, nil)
                  @attachment.expects(:instance_write).with(:file_size, nil)
                  @attachment.expects(:instance_write).with(:fingerprint, nil)
                  @attachment.expects(:instance_write).with(:updated_at, nil)
                  @attachment.clear
                  @attachment.save
                  @existing_names.each{|f| assert_file_exists(f) }
                end

                should "keep the files when you call #delete" do
                  @attachment.expects(:instance_write).with(:file_name, nil)
                  @attachment.expects(:instance_write).with(:content_type, nil)
                  @attachment.expects(:instance_write).with(:file_size, nil)
                  @attachment.expects(:instance_write).with(:fingerprint, nil)
                  @attachment.expects(:instance_write).with(:updated_at, nil)
                  @attachment.destroy
                  @existing_names.each{|f| assert_file_exists(f) }
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
        assert_raise(Paperclip::Errors::StorageMethodNotFound){ Dummy.new.avatar }
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
      @file = File.new(fixture_file("5k.png"), 'rb')
    end

    teardown { @file.close }

    should "not error when assigned an attachment" do
      assert_nothing_raised { @dummy.avatar = @file }
    end

    should "not return the time when sent #avatar_updated_at" do
      @dummy.avatar = @file
      assert_nil @dummy.avatar.updated_at
    end

    should "return the right value when sent #avatar_file_size" do
      @dummy.avatar = @file
      assert_equal File.size(@file), @dummy.avatar.size
    end

    context "and avatar_created_at column" do
      setup do
        ActiveRecord::Base.connection.add_column :dummies, :avatar_created_at, :timestamp
        rebuild_class
        @dummy = Dummy.new
      end

      should "not error when assigned an attachment" do
        assert_nothing_raised { @dummy.avatar = @file }
      end

      should "return the creation time when sent #avatar_created_at" do
        now = Time.now
        Time.stubs(:now).returns(now)
        @dummy.avatar = @file
        assert_equal now.to_i, @dummy.avatar.created_at
      end

      should "return the creation time when sent #avatar_created_at and the entry has been updated" do
        creation = 2.hours.ago
        now = Time.now
        Time.stubs(:now).returns(creation)
        @dummy.avatar = @file
        Time.stubs(:now).returns(now)
        @dummy.avatar = @file
        assert_equal creation.to_i, @dummy.avatar.created_at
        assert_not_equal now.to_i, @dummy.avatar.created_at
      end

      should "set changed? to true on attachment assignment" do
        @dummy.avatar = @file
        @dummy.save!
        @dummy.avatar = @file
        assert @dummy.changed?
      end
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

    should "not calculate fingerprint" do
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
        assert_equal File.size(@file), @dummy.avatar.size
      end

      should "return the right value when saved, reloaded, and sent #avatar_file_size" do
        @dummy.avatar = @file
        @dummy.save
        @dummy = Dummy.find(@dummy.id)
        assert_equal File.size(@file), @dummy.avatar.size
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
      @file = File.new(fixture_file("5k.png"), 'rb')
      @dummy.avatar = @file
      @dummy.save!
      @attachment = @dummy.avatar
      @path = @attachment.path
    end

    teardown { @file.close }

    should "not delete the files from storage when attachment is destroyed" do
      @attachment.destroy
      assert_file_exists(@path)
    end

    should "clear out attachment data when attachment is destroyed" do
      @attachment.destroy
      assert !@attachment.exists?
      assert_nil @dummy.avatar_file_name
    end

    should "not delete the file when model is destroyed" do
      @dummy.destroy
      assert_file_exists(@path)
    end
  end

  context "An attached file" do
    setup do
      rebuild_model
      @dummy = Dummy.new
      @file = File.new(fixture_file("5k.png"), 'rb')
      @dummy.avatar = @file
      @dummy.save!
      @attachment = @dummy.avatar
      @path = @attachment.path
    end

    teardown { @file.close }

    should "not be deleted when the model fails to destroy" do
      @dummy.stubs(:destroy).raises(Exception)

      assert_raise Exception do
        @dummy.destroy
      end

      assert_file_exists(@path)
    end

    should "be deleted when the model is destroyed" do
      @dummy.destroy
      assert_file_not_exists(@path)
    end

    should "not be deleted when transaction rollbacks after model is destroyed" do
      ActiveRecord::Base.transaction do
        @dummy.destroy
        raise ActiveRecord::Rollback
      end

      assert_file_exists(@path)
    end
  end

end
