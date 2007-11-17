require 'test/unit'
require File.dirname(__FILE__) + "/test_helper.rb"

class TestAttachment < Test::Unit::TestCase
  context "An attachment" do
    setup do
      @dummy = {}
      @definition = Paperclip::AttachmentDefinition.new("thing", {})
      @attachment = Paperclip::Attachment.new(@dummy, "thing", @definition)
    end
  end

  context "The class Foo" do
    setup do
      ActiveRecord::Base.connection.create_table :foos, :force => true do |table|
        table.column :image_file_name, :string
        table.column :image_content_type, :string
        table.column :image_file_size, :integer

        table.column :document_file_name, :string
        table.column :document_content_type, :string
        table.column :document_file_size, :integer
      end
      Object.send(:remove_const, :Foo) rescue nil
      class ::Foo < ActiveRecord::Base; end
    end

    context "with an image attached to :image" do
      setup do
        assert Foo.has_attached_file(:image)
        @foo = Foo.new
        @file = File.new(File.join(File.dirname(__FILE__), "fixtures", "test_image.jpg"))
        assert_nothing_raised{ @foo.image = @file }
      end

      should "be able to have a file assigned with :image=" do
        assert_equal "test_image.jpg", @foo.image.original_filename
        assert_equal "image/jpg", @foo.image.content_type
      end

      should "be able to retrieve the data as a blob" do
        @file.rewind
        assert_equal @file.read, @foo.image.read
      end

      context "and saved" do
        setup do
          assert @foo.save
        end

        should "have no errors" do
          assert @foo.image.errors.blank?
          assert @foo.errors.blank?
        end

        should "have a file on the filesystem" do
          assert @foo.image.send(:file_name)
          assert File.file?(@foo.image.send(:file_name)), @foo.image.send(:file_name)
          assert File.size(@foo.image.send(:file_name)) > 0
          assert_match /405x375/, `identify '#{@foo.image.send(:file_name)}'`
          assert_equal IO.read(@file.path), @foo.image.read
        end
      end
    end

    context "with an image with thumbnails attached to :image and saved" do
      setup do
        assert Foo.has_attached_file(:image, :thumbnails => {:small => "16x16", :medium => "100x100", :large => "250x250", :square => "32x32#"})
        @foo = Foo.new
        @file = File.new(File.join(File.dirname(__FILE__), "fixtures", "test_image.jpg"))
        assert_nothing_raised{ @foo.image = @file }
        assert @foo.save
      end

      should "have no errors" do
        assert @foo.image.errors.blank?, @foo.image.errors.inspect
        assert @foo.errors.blank?
      end

      [:original, :small, :medium, :large, :square].each do |style|
        should "have a file for #{style} on the filesystem" do
          assert @foo.image.send(:file_name)
          assert File.file?(@foo.image.send(:file_name)), @foo.image.send(:file_name)
          assert File.size(@foo.image.send(:file_name)) > 0
          assert_equal IO.read(@file.path), @foo.image.read
        end

        should "return the correct urls when asked for the #{style} image" do
          assert_equal "/foos/images/1/#{style}_test_image.jpg", @foo.image.url(style)
        end
      end

      should "produce the correct dimensions when each style is identified" do
        assert_match /16x15/,   `identify '#{@foo.image.send(:file_name, :small)}'`
        assert_match /32x32/,   `identify '#{@foo.image.send(:file_name, :square)}'`  
        assert_match /100x93/,  `identify '#{@foo.image.send(:file_name, :medium)}'`
        assert_match /250x231/, `identify '#{@foo.image.send(:file_name, :large)}'`
        assert_match /405x375/, `identify '#{@foo.image.send(:file_name, :original)}'`
      end
    end

    context "with an image with thumbnails attached to :image and a document attached to :document" do
    end

    context "with an invalid image with a square thumbnail attached to :image" do
      setup do
        assert Foo.has_attached_file(:image, :thumbnails => {:square => "32x32#"})
        assert Foo.validates_attached_file(:image)
        @foo = Foo.new
        @file = File.new(File.join(File.dirname(__FILE__), "fixtures", "test_invalid_image.jpg"))
        assert_nothing_raised{ @foo.image = @file }
      end

      should "not save and should report errors from identify" do
        assert !@foo.save
        assert @foo.errors.on(:image)
        assert @foo.errors.on(:image).any?{|e| e.match(/does not contain a valid image/) }, @foo.errors.on(:image)
      end
    end
    
    context "with an invalid image attached to :image" do
      setup do
        assert Foo.has_attached_file(:image, :thumbnails => {:sorta_square => "32x32"})
        assert Foo.validates_attached_file(:image)
        @foo = Foo.new
        @file = File.new(File.join(File.dirname(__FILE__), "fixtures", "test_invalid_image.jpg"))
        assert_nothing_raised{ @foo.image = @file }
      end

      should "not save and should report errors from convert" do
        assert !@foo.save
        assert @foo.errors.on(:image)
        assert @foo.errors.on(:image).any?{|e| e.match(/because of an error/) }, @foo.errors.on(:image)
      end
    end
  end  
end