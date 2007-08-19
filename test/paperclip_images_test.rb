require 'test/unit'
require File.dirname(__FILE__) + "/test_helper.rb"
require File.dirname(__FILE__) + "/../init.rb"
require File.join(File.dirname(__FILE__), "models.rb")

class PaperclipImagesTest < Test::Unit::TestCase
  def setup
    assert @foo = Foo.new
    assert @file = File.new(File.join(File.dirname(__FILE__), 'fixtures', 'test_image.jpg'))
    assert @foo.image = @file
  end

  def test_should_validate_before_save
    assert @foo.image_valid?
    assert @foo.valid?
  end

  def test_should_save_the_file_and_its_thumbnails
    assert @foo.save
    assert File.exists?( @foo.image_file_name(:original) ), @foo.image_file_name(:original)
    assert File.exists?( @foo.image_file_name(:medium) ), @foo.image_file_name(:medium)
    assert File.exists?( @foo.image_file_name(:thumb) ), @foo.image_file_name(:thumb)
    assert File.size?(   @foo.image_file_name(:original) )
    assert File.size?(   @foo.image_file_name(:medium) )
    assert File.size?(   @foo.image_file_name(:thumb) )
    out = `identify '#{@foo.image_file_name(:original)}'`; assert out.match("405x375"); assert $?.exitstatus == 0
    out = `identify '#{@foo.image_file_name(:medium)}'`;   assert out.match("300x278"); assert $?.exitstatus == 0
    out = `identify '#{@foo.image_file_name(:thumb)}'`;    assert out.match("100x93");  assert $?.exitstatus == 0
  end

  def test_should_validate_to_make_sure_the_thumbnails_exist
    assert @foo.save
    assert @foo.image_valid?
    assert @foo.valid?
  end
  
  def test_should_delete_all_thumbnails_on_destroy
    assert @foo.save
    names = [:original, :medium, :thumb].map{|style| @foo.image_file_name(style) }
    assert @foo.destroy
    names.each {|path| assert !File.exists?( path ), path }
  end
  
end