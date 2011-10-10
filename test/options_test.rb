# encoding: utf-8
require './test/helper'

class MockAttachment < Struct.new(:one, :two)
  def instance
    self
  end
end

class OptionsTest < Test::Unit::TestCase
  should "be able to set a value" do
    @options = Paperclip::Options.new(nil, {})
    assert_nil @options.path
    @options.path = "this/is/a/path"
    assert_equal "this/is/a/path", @options.path
  end

  context "#styles with a plain hash" do
    setup do
      @attachment = MockAttachment.new(nil, nil)
      @options = Paperclip::Options.new(@attachment,
                                        :styles => {
                                          :something => ["400x400", :png]
                                        })
    end

    should "return the right data for the style's geometry" do
      assert_equal "400x400", @options.styles[:something][:geometry]
    end

    should "return the right data for the style's format" do
      assert_equal :png, @options.styles[:something][:format]
    end
  end

  context "#styles is a proc" do
    setup do
      @attachment = MockAttachment.new("123x456", :doc)
      @options = Paperclip::Options.new(@attachment,
                                        :styles => lambda {|att|
                                          {:something => {:geometry => att.one, :format => att.two}}
                                        })
    end

    should "return the right data for the style's geometry" do
      assert_equal "123x456", @options.styles[:something][:geometry]
    end

    should "return the right data for the style's format" do
      assert_equal :doc, @options.styles[:something][:format]
    end

    should "run the proc each time, giving dynamic results" do
      assert_equal :doc, @options.styles[:something][:format]
      @attachment.two = :pdf
      assert_equal :pdf, @options.styles[:something][:format]
    end
  end

  context "#processors" do
    setup do
      @attachment = MockAttachment.new(nil, nil)
    end
    should "return processors if not a proc" do
      @options = Paperclip::Options.new(@attachment, :processors => [:one])
      assert_equal [:one], @options.processors
    end
    should "return processors if it is a proc" do
      @options = Paperclip::Options.new(@attachment, :processors => lambda{|att| [att.one]})
      assert_equal [nil], @options.processors
      @attachment.one = :other
      assert_equal [:other], @options.processors
    end
  end
end
