require 'test/unit'
require File.dirname(__FILE__) + "/test_helper.rb"
require File.dirname(__FILE__) + "/../init.rb"
require File.join(File.dirname(__FILE__), "models.rb")

class PaperclipTest < Test::Unit::TestCase
  def setup
    assert @bar = Bar.new
    assert @file = File.new(File.join(File.dirname(__FILE__), 'fixtures', 'test_document.doc'))
    assert @bar.document = @file
  end

  def test_should_validate_before_save
    assert @bar.document_valid?
    assert @bar.valid?
  end

  def test_should_save_the_created_file_to_the_final_asset_directory
    assert @bar.save
    assert File.exists?( @bar.document_filename )
  end

  def test_should_validate
    assert @bar.save
    assert @bar.document_valid?
    assert @bar.valid?
  end
  
  def test_should_default_to_original_for_path_and_url
    assert_equal @bar.document_filename(:original), @bar.document_filename
    assert_equal @bar.document_url(:original), @bar.document_url
  end
  
  def test_should_delete_files_on_destroy
    assert @bar.save
    assert File.exists?( @bar.document_filename )
    
    assert @bar.destroy
    assert !File.exists?( @bar.document_filename )
  end

end