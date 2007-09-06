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
    assert File.exists?( @bar.document_file_name )
  end

  def test_should_validate
    assert @bar.save
    assert @bar.document_valid?
    assert @bar.valid?
  end
  
  def test_should_default_to_original_for_path_and_url
    assert_equal @bar.document_file_name(:original), @bar.document_file_name
    assert_equal @bar.document_url(:original), @bar.document_url
  end
  
  def test_should_delete_files_on_destroy
    assert @bar.save
    assert File.exists?( @bar.document_file_name ), @bar.document_file_name
    
    document_file_name = @bar.document_file_name
    assert @bar.destroy
    assert !File.exists?( document_file_name ), document_file_name
  end
  
  def test_should_put_on_errors_if_no_file_exists
    assert @bar.save
    @bar.document = nil
    assert !@bar.document_valid?
    assert !@bar.save
    assert @bar.errors.length > 0
    assert @bar.errors.on(:document)
    assert_match /requires a valid/, @bar.errors.on(:document), @bar.errors.on(:document)
  end
  
  def test_should_raise_if_table_missing_columns
    assert_raises Thoughtbot::Paperclip::PaperclipError do
      Negative.send(:has_attached_file, :missing)
    end
  end

end