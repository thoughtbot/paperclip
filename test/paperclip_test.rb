require 'test/unit'
require File.dirname(__FILE__) + "/test_helper.rb"
require File.dirname(__FILE__) + "/simply_shoulda.rb"
require File.dirname(__FILE__) + "/../init.rb"

class PaperclipTest < Test::Unit::TestCase

  context "Paperclip" do
    should "allow overriding options" do
      not_expected = Paperclip.options[:image_magick_path]
      Paperclip.options[:image_magick_path] = "123"
      assert_equal "123", Paperclip.options[:image_magick_path]
    end

    should "give the correct path for a command" do
      expected = "/usr/bin/wtf"
      Paperclip.options[:image_magick_path] = "/usr/bin"
      assert_equal expected, Paperclip.path_for_command("wtf")
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
      end

      should "be able to assign two attachments separately" do
        assert Foo.has_attached_file(:image)
        assert Foo.has_attached_file(:document)
        assert_equal [:image, :document], Foo.attached_files
      end

      should "be able to assign two attachments simultaneously" do
        assert Foo.has_attached_file(:image, :document)
        assert_equal [:image, :document], Foo.attached_files
      end

      should "be able to set options on attachments" do
        assert Foo.has_attached_file :image, :thumbnails => {:thumb => "100x100"}
        assert_equal [:image], Foo.attached_files
        assert_equal( {:thumb => "100x100"}, Foo.attachment_definition_for(:image).thumbnails )
      end
    end

  end

end