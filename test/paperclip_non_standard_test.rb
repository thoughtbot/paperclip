require 'test/unit'
require File.dirname(__FILE__) + "/test_helper.rb"
require File.dirname(__FILE__) + "/../init.rb"
require File.join(File.dirname(__FILE__), "models.rb")

class PaperclipNonStandardTest < Test::Unit::TestCase
  def setup
    assert @ns = NonStandard.new
    assert @resume = File.new(File.join(File.dirname(__FILE__), 'fixtures', 'test_document.doc'))
    assert @avatar = File.new(File.join(File.dirname(__FILE__), 'fixtures', 'test_image.jpg'))
    assert @ns.resume = @resume
    assert @ns.avatar = @avatar
  end
  
  def test_should_supply_all_attachment_names
    assert_equal %w( avatar resume ), NonStandard.attachment_names.map{|a| a.to_s }.sort
  end

  def test_should_validate_before_save
    assert @ns.avatar_valid?
    assert @ns.valid?
  end

  def test_should_save_the_created_file_to_the_final_asset_directory
    assert @ns.save
    assert File.exists?( @ns.resume_file_name ), @ns.resume_file_name
    assert File.exists?( @ns.avatar_file_name(:original) ), @ns.avatar_file_name(:original)
    assert File.exists?( @ns.avatar_file_name(:bigger) )
    assert File.exists?( @ns.avatar_file_name(:cropped) )
    assert File.size?(   @ns.avatar_file_name(:original) )
    assert File.size?(   @ns.avatar_file_name(:bigger) )
    assert File.size?(   @ns.avatar_file_name(:cropped) )
    out = `identify '#{@ns.avatar_file_name(:original)}'`; assert_match /405x375/, out, out;  assert $?.exitstatus == 0
    out = `identify '#{@ns.avatar_file_name(:bigger)}'`;   assert_match /1000x926/, out, out; assert $?.exitstatus == 0
    out = `identify '#{@ns.avatar_file_name(:cropped)}'`;  assert_match /200x10/, out, out;   assert $?.exitstatus == 0
  end

  def test_should_validate
    assert @ns.save
    assert @ns.resume_valid?
    assert @ns.avatar_valid?
    assert @ns.valid?
  end

  def test_should_default_to_the_assigned_default_style_for_path_and_url
    assert_equal @ns.resume_file_name(:original), @ns.resume_file_name
    assert_equal @ns.resume_url(:original), @ns.resume_url

    assert_equal @ns.avatar_file_name(:square), @ns.avatar_file_name
    assert_equal @ns.avatar_url(:square), @ns.avatar_url
  end

  def test_should_delete_files_on_destroy
    assert @ns.save
    assert File.exists?( @ns.resume_file_name ), @ns.resume_file_name
    [:original, :bigger, :cropped].each do |style|
      assert File.exists?( @ns.avatar_file_name(style) ), @ns.avatar_file_name(style)
    end

    resume_file_name  = @ns.resume_file_name
    avatar_file_names = [:original, :bigger, :cropped].map{|style| @ns.avatar_file_name(style) }
    assert @ns.destroy
    assert !File.exists?( resume_file_name ), resume_file_name
    avatar_file_names.each do |name|
      assert !File.exists?(name), name
    end
  end
  
  def test_should_return_missing_url_interpolated_when_no_attachment_exists
    assert @ns.save
    assert @ns.destroy_resume
    assert @ns.destroy_avatar
    assert_equal "/non_standards/original/resumes/404.txt", @ns.resume_url
    assert_equal "/non_standards/bigger/avatars/404.png", @ns.avatar_url(:bigger)
    assert_equal "/non_standards/original/avatars/404.png", @ns.avatar_url(:original)
    assert_equal "/non_standards/square/avatars/404.png", @ns.avatar_url
  end

end