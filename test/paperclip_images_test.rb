require 'test/unit'
require 'uri'
require File.dirname(__FILE__) + "/test_helper.rb"
require File.dirname(__FILE__) + "/../init.rb"
require File.join(File.dirname(__FILE__), "models.rb")

class PaperclipImagesTest < Test::Unit::TestCase
  def setup
    assert @foo       = Foo.new
    assert @file      = File.new(File.join(File.dirname(__FILE__), 'fixtures', 'test_image.jpg'))
    assert @document  = File.new(File.join(File.dirname(__FILE__), 'fixtures', 'test_document.doc'))
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
  
  def test_should_ensure_that_file_are_accessible_after_reload
    assert @foo.save
    assert @foo.image_valid?
    assert @foo.valid?
    
    @foo2 = Foo.find @foo.id
    assert @foo.image_valid?
    assert File.exists?( @foo.image_file_name(:original) ), @foo.image_file_name(:original)
    assert File.exists?( @foo.image_file_name(:medium) ), @foo.image_file_name(:medium)
    assert File.exists?( @foo.image_file_name(:thumb) ), @foo.image_file_name(:thumb)
    out = `identify '#{@foo.image_file_name(:original)}'`; assert out.match("405x375"); assert $?.exitstatus == 0
    out = `identify '#{@foo.image_file_name(:medium)}'`;   assert out.match("300x278"); assert $?.exitstatus == 0
    out = `identify '#{@foo.image_file_name(:thumb)}'`;    assert out.match("100x93");  assert $?.exitstatus == 0
  end
  
  def test_should_delete_all_thumbnails_on_destroy
    assert @foo.save
    names = [:original, :medium, :thumb].map{|style| @foo.image_file_name(style) }
    assert @foo.destroy
    names.each {|path| assert !File.exists?( path ), path }
  end
  
  def test_should_ensure_file_names_and_urls_are_empty_if_no_file_set
    assert @foo.save
    assert @foo.image_valid?
    mappings = [:original, :medium, :thumb].map do |style|
      assert @foo.image_file_name(style)
      assert @foo.image_url(style)
      [style, @foo.image_file_name(style), @foo.image_url(style)]
    end
    
    assert @foo.destroy_image
    assert @foo.save
    mappings.each do |style, file, url|
      assert_not_equal file, @foo.image_file_name(style)
      assert_equal "", @foo.image_file_name(style)
      assert_not_equal url, @foo.image_url(style)
      assert_equal "", @foo.image_url(style)
    end
    
    assert @foo2 = Foo.find(@foo.id)
    mappings.each do |style, file, url|
      assert_not_equal file, @foo2.image_file_name(style)
      assert_equal "", @foo2.image_file_name(style)
      assert_not_equal url, @foo2.image_url(style)
      assert_equal "", @foo2.image_url(style)
    end
    
    assert @foo3 = Foo.new
    mappings.each do |style, file, url|
      assert_equal "", @foo3.image_file_name(style), @foo3["image_file_name"]
      assert_equal "", @foo3.image_url(style)
    end
  end
  
  def test_should_save_image_from_uri
    require 'webrick'
    server = WEBrick::HTTPServer.new(:Port         => 40404,
                                     :DocumentRoot => File.dirname(__FILE__),
                                     :AccessLog    => [],
                                     :Logger       => WEBrick::Log.new(nil, WEBrick::Log::WARN))
    Thread.new do
      server.start
    end
    while server.status != :Running
      sleep 0.1
      print "!"; $stdout.flush
    end
    
    uri = URI.parse("http://127.0.0.1:40404/fixtures/test_image.jpg")
    @foo.image = uri
    @foo.save
    @foo.image_valid?
    assert File.exists?( @foo.image_file_name(:original) ), @foo.image_file_name(:original)
    assert File.exists?( @foo.image_file_name(:medium) ), @foo.image_file_name(:medium)
    assert File.exists?( @foo.image_file_name(:thumb) ), @foo.image_file_name(:thumb)
    out = `identify '#{@foo.image_file_name(:original)}'`; assert_match "405x375", out; assert $?.exitstatus == 0
    out = `identify '#{@foo.image_file_name(:medium)}'`;   assert_match "300x278", out;  assert $?.exitstatus == 0
    out = `identify '#{@foo.image_file_name(:thumb)}'`;    assert_match "100x93", out;  assert $?.exitstatus == 0
  ensure
    server.stop if server
  end

  def test_should_put_errors_on_object_if_convert_does_not_exist
    old_path = Thoughtbot::Paperclip.options[:image_magick_path]
    Thoughtbot::Paperclip.options[:image_magick_path] = "/does/not/exist"

    assert_nothing_raised{ @foo.image = @file }
    assert !@foo.save
    assert !@foo.valid?
    assert @foo.errors.length > 0
    assert @foo.errors.on(:image)
    [@foo.errors.on(:image)].flatten.each do |err|
      assert_match /could not/, err, err
    end
  ensure
    Thoughtbot::Paperclip.options[:image_magick_path] = old_path
  end

  def test_should_put_errors_on_object_if_convert_fails
    assert_nothing_raised{ @foo.image = @document }
    assert !@foo.save
    assert !@foo.valid?
    assert @foo.errors.length > 0
    assert @foo.errors.on(:image)
    [@foo.errors.on(:image)].flatten.each do |err|
      assert_match /could not/, err, err
    end
  end

end