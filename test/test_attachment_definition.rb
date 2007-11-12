require 'test/unit'
require File.dirname(__FILE__) + "/test_helper.rb"

class TestAttachmentDefinition < Test::Unit::TestCase
  context "Attachment definitions" do  
    should "allow overriding options" do
      not_expected = Paperclip::AttachmentDefinition.defaults[:path]
      Paperclip::AttachmentDefinition.defaults[:path] = "123"
      assert_not_equal not_expected, Paperclip::AttachmentDefinition.defaults[:path]
      assert_equal "123", Paperclip::AttachmentDefinition.defaults[:path]
    end
    
    should "accept options that override defaults" do
      @def = Paperclip::AttachmentDefinition.new "attachment", :path => "123", :delete_on_destroy => false
      assert_not_equal Paperclip::AttachmentDefinition.defaults[:path], @def.path
      assert_not_equal Paperclip::AttachmentDefinition.defaults[:delete_on_destroy], @def.delete_on_destroy
      assert_equal "123", @def.path
      assert_equal false, @def.delete_on_destroy
    end
  end
  
  context "An attachment defintion" do
    setup do
      @options = {
        :path => "/home/stuff/place",
        :url => "/attachments/:attachment/:name",
        :custom_definition => :boogie!,
        :thumbnails => {:thumb => "100x100", :large => "300x300>"},
        :validates_existance => true,
        :validates_size => [0, 2048]
      }
      @def = Paperclip::AttachmentDefinition.new "attachment", @options
    end
    
    should "automatically look in the hash for missing methods" do
      assert ! @def.respond_to?(:custom_defintion)
      assert_equal :boogie!, @def.custom_definition
    end
    
    should "be able to read options using attribute readers" do
      @options.keys.each do |key|
        assert_equal @options[key], @def.send(key)
      end
    end
    
    should "return styles as thumbnails plus the original" do
      assert( (@def.thumbnails.keys + [:original]).map(&:to_s).sort == @def.styles.keys.map(&:to_s).sort )
    end
    
    should "return all validations when sent :validations" do
      assert @def.validations[:existance] == true, @def.validations[:existance]
      assert @def.validations[:size] == [0, 2048], @def.validations[:size]
    end
  end
  
end