# encoding: utf-8
require './test/helper'

class StyleTest < Test::Unit::TestCase

  context "A style rule" do
    setup do
      @attachment = attachment :path => ":basename.:extension",
                               :styles => { :foo => {:geometry => "100x100#", :format => :png} },
                               :whiny => true
      @style = @attachment.options.styles[:foo]
    end

    should "be held as a Style object" do
      assert_kind_of Paperclip::Style, @style
    end

    should "get processors from the attachment definition" do
      assert_equal [:thumbnail], @style.processors
    end

    should "have the right geometry" do
      assert_equal "100x100#", @style.geometry
    end

    should "be whiny if the attachment is" do
      assert @style.whiny?
    end

    should "respond to hash notation" do
      assert_equal [:thumbnail], @style[:processors]
      assert_equal "100x100#", @style[:geometry]
    end
  end

  context "A style rule with properties supplied as procs" do
    setup do
      @attachment = attachment :path => ":basename.:extension",
                               :whiny_thumbnails => true,
                               :processors => lambda {|a| [:test]},
                               :styles => {
                                 :foo => lambda{|a| "300x300#"},
                                 :bar => {
                                   :geometry => lambda{|a| "300x300#"}
                                 }
                               }
    end

    should "call procs when they are needed" do
      assert_equal "300x300#", @attachment.options.styles[:foo].geometry
      assert_equal "300x300#", @attachment.options.styles[:bar].geometry
      assert_equal [:test], @attachment.options.styles[:foo].processors
      assert_equal [:test], @attachment.options.styles[:bar].processors
    end
  end

  context "An attachment with style rules in various forms" do
    setup do
      styles = ActiveSupport::OrderedHash.new
      styles[:aslist] = ["100x100", :png]
      styles[:ashash] = {:geometry => "100x100", :format => :png}
      styles[:asstring] = "100x100"
      @attachment = attachment :path => ":basename.:extension",
                               :styles => styles
    end
    should "have the right number of styles" do
      assert_kind_of Hash, @attachment.options.styles
      assert_equal 3, @attachment.options.styles.size
    end

    should "have styles as Style objects" do
      [:aslist, :ashash, :aslist].each do |s|
        assert_kind_of Paperclip::Style, @attachment.options.styles[s]
      end
    end

    should "have the right geometries" do
      [:aslist, :ashash, :aslist].each do |s|
        assert_equal @attachment.options.styles[s].geometry, "100x100"
      end
    end

    should "have the right formats" do
      assert_equal @attachment.options.styles[:aslist].format, :png
      assert_equal @attachment.options.styles[:ashash].format, :png
      assert_nil @attachment.options.styles[:asstring].format
    end

    should "retain order" do
      assert_equal [:aslist, :ashash, :asstring], @attachment.options.styles.keys
    end
  end

  context "An attachment with :convert_options" do
    setup do
      @attachment = attachment :path => ":basename.:extension",
                               :styles => {:thumb => "100x100", :large => "400x400"},
                               :convert_options => {:all => "-do_stuff", :thumb => "-thumbnailize"}
      @style = @attachment.options.styles[:thumb]
      @file = StringIO.new("...")
      @file.stubs(:original_filename).returns("file.jpg")
    end

    before_should "not have called extra_options_for(:thumb/:large) on initialization" do
      @attachment.expects(:extra_options_for).never
    end

    should "call extra_options_for(:thumb/:large) when convert options are requested" do
      @attachment.expects(:extra_options_for).with(:thumb)
      @attachment.options.styles[:thumb].convert_options
    end
  end

  context "An attachment with :source_file_options" do
    setup do
      @attachment = attachment :path => ":basename.:extension",
                               :styles => {:thumb => "100x100", :large => "400x400"},
                               :source_file_options => {:all => "-density 400", :thumb => "-depth 8"}
      @style = @attachment.options.styles[:thumb]
      @file = StringIO.new("...")
      @file.stubs(:original_filename).returns("file.jpg")
    end

    before_should "not have called extra_source_file_options_for(:thumb/:large) on initialization" do
      @attachment.expects(:extra_source_file_options_for).never
    end

    should "call extra_options_for(:thumb/:large) when convert options are requested" do
      @attachment.expects(:extra_source_file_options_for).with(:thumb)
      @attachment.options.styles[:thumb].source_file_options
    end
  end

  context "A style rule with its own :processors" do
    setup do
      @attachment = attachment :path => ":basename.:extension",
                               :styles => {
                                 :foo => {
                                   :geometry => "100x100#",
                                   :format => :png,
                                   :processors => [:test]
                                  }
                                },
                               :processors => [:thumbnail]
      @style = @attachment.options.styles[:foo]
    end

    should "not get processors from the attachment" do
      @attachment.expects(:processors).never
      assert_not_equal [:thumbnail], @style.processors
    end

    should "report its own processors" do
      assert_equal [:test], @style.processors
    end

  end

  context "A style rule with :processors supplied as procs" do
    setup do
      @attachment = attachment :path => ":basename.:extension",
                               :styles => {
                                 :foo => {
                                   :geometry => "100x100#",
                                   :format => :png,
                                   :processors => lambda{|a| [:test]}
                                  }
                                },
                               :processors => [:thumbnail]
    end

    should "defer processing of procs until they are needed" do
      assert_kind_of Proc, @attachment.options.styles[:foo].instance_variable_get("@processors")
    end

    should "call procs when they are needed" do
      assert_equal [:test], @attachment.options.styles[:foo].processors
    end
  end
end
