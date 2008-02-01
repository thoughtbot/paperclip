require 'test/unit'
require File.dirname(__FILE__) + "/test_helper.rb"

class TestPaperclip < Test::Unit::TestCase

  context "Paperclip" do
    should "allow overriding options" do
      [:image_magick_path, :whiny_deletes, :whiny_thumbnails].each do |option|
        not_expected = Paperclip.options[option]
        Paperclip.options[option] = "123"
        assert_equal "123", Paperclip.options[option]
        assert_not_equal not_expected, Paperclip.options[option]
      end
    end

    should "give the correct path for a command" do
      expected = "/usr/bin/wtf"
      Paperclip.options[:image_magick_path] = "/usr/bin"
      assert_equal expected, Paperclip.path_for_command("wtf")

      expected = "wtf"
      Paperclip.options[:image_magick_path] = nil
      assert_equal expected, Paperclip.path_for_command("wtf")
    end
    
    context "being used on improper class Improper" do
      setup do
        ActiveRecord::Base.connection.create_table :impropers, :force => true do |table|
          # Empty table
        end
        Object.send(:remove_const, :Improper) rescue nil
        class ::Improper < ActiveRecord::Base; end
      end
      
      should "raises an error when an attachment is defined" do
        assert_raises(Paperclip::PaperclipError){ Improper.has_attached_file :image }
      end

      [:file_name, :content_type].each do |column|
        context "which has only the #{column} column" do
          setup do
            ActiveRecord::Base.connection.create_table :impropers, :force => true do |table|
              table.column :"image_#{column}", :string
            end
            Object.send(:remove_const, :Improper) rescue nil
            class ::Improper < ActiveRecord::Base; end
          end
          should "raises an error when an attachment is defined" do
            assert_raises(Paperclip::PaperclipError){ Improper.has_attached_file :image }
          end
        end
      end
    end

    context "being used on class Foo" do
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

      should "be able to assign a default attachment" do
        assert Foo.has_attached_file(:image)
        assert_equal [:image], Foo.attached_files
        foo = Foo.new
        assert foo.respond_to?(:image)
        assert foo.image.is_a?(Paperclip::Attachment)
      end

      should "be able to assign two attachments separately" do
        assert Foo.has_attached_file(:image)
        assert Foo.has_attached_file(:document)
        assert_equal [:image, :document], Foo.attached_files
        foo = Foo.new
        assert foo.respond_to?(:image)
        assert foo.respond_to?(:document)
        assert foo.image.is_a?(Paperclip::Attachment)
        assert foo.document.is_a?(Paperclip::Attachment)
        assert foo.image != foo.document
      end

      should "be able to assign two attachments simultaneously" do
        assert Foo.has_attached_file(:image, :document)
        assert_equal [:image, :document], Foo.attached_files
        foo = Foo.new
        assert foo.respond_to?(:image)
        assert foo.respond_to?(:document)
        assert foo.image.is_a?(Paperclip::Attachment)
        assert foo.document.is_a?(Paperclip::Attachment)
        assert foo.image != foo.document
      end

      should "be able to set options on attachments" do
        assert Foo.has_attached_file :image, :thumbnails => {:thumb => "100x100"}
        assert_equal [:image], Foo.attached_files
        assert_equal( {:thumb => "100x100"}, Foo.attachment_definition_for(:image).thumbnails )
        foo = Foo.new
        assert foo.respond_to?(:image)
        assert foo.image.is_a?(Paperclip::Attachment)
      end
    end

  end

end