require 'test/helper'

module ActionController
  class Base
    def self.relative_url_root
      '/base'
    end
  end
end

def rebuild_database_table_1_blob_column options = {}
  ActiveRecord::Base.connection.create_table :dummies, :force => true do |table|
    table.column :other, :string
    table.column :avatar_file_name, :string
    table.column :avatar_content_type, :string
    table.column :avatar_file_size, :integer
    table.column :avatar_updated_at, :datetime
    table.column :avatar_file, :binary
  end
end

def rebuild_database_table_3_default_blob_columns options = {}
  ActiveRecord::Base.connection.create_table :dummies, :force => true do |table|
    table.column :other, :string
    table.column :avatar_file_name, :string
    table.column :avatar_content_type, :string
    table.column :avatar_file_size, :integer
    table.column :avatar_updated_at, :datetime
    table.column :avatar_file, :binary
    table.column :avatar_thumb_file, :binary
    table.column :avatar_medium_file, :binary
  end
end

def rebuild_database_table_3_custom_blob_columns options = {}
  ActiveRecord::Base.connection.create_table :dummies, :force => true do |table|
    table.column :other, :string
    table.column :avatar_file_name, :string
    table.column :avatar_content_type, :string
    table.column :avatar_file_size, :integer
    table.column :avatar_updated_at, :datetime
    table.column :avatar_file_data, :binary
    table.column :thumb_file_data, :binary
    table.column :medium_file_data, :binary
  end
end

class DatabaseStorageTest < Test::Unit::TestCase

  context "An attachment with database storage and default options" do
    setup do
      rebuild_database_table_1_blob_column
      rebuild_class :storage => :database
    end
    
    should "be extended by the database storage module" do
      assert Dummy.new.avatar.is_a?(Paperclip::Storage::Database)
    end
    
    should "return the meta data columns from select_without_file_columns_for" do
      assert_equal Dummy.select_without_file_columns_for(:avatar),
                   { :select=>"id,other,avatar_file_name,avatar_content_type,avatar_file_size,avatar_updated_at" }
    end    
  end

  context "An attachment with database storage and array style options" do
    setup do
      rebuild_database_table_1_blob_column
      rebuild_class :storage => :database, :styles => {:original => ["200x200", :jpg ]}
    end

    should "be extended by the database storage module" do
      assert Dummy.new.avatar.is_a?(Paperclip::Storage::Database)
    end

    should "return the meta data columns from select_without_file_columns_for" do
      assert_equal Dummy.select_without_file_columns_for(:avatar),
                   { :select=>"id,other,avatar_file_name,avatar_content_type,avatar_file_size,avatar_updated_at" }
    end
  end

  context "An attachment with database storage, default options plus two styles" do
    setup do
      rebuild_database_table_3_default_blob_columns
      rebuild_class :storage => :database,
        :styles => { 
          :medium => {:geometry => "300x300>"},
          :thumb => {:geometry => "100x100>"}
        }
    end
    
    should "return the meta data columns from select_without_file_columns_for" do
      assert_equal Dummy.select_without_file_columns_for(:avatar),
                   { :select=>"id,other,avatar_file_name,avatar_content_type,avatar_file_size,avatar_updated_at" }
    end
  end

  context "An attachment with database storage and incorrect original style column name" do
    setup do
      rebuild_database_table_1_blob_column
    end
    
    should "raise an exception" do
      assert_raises(Paperclip::PaperclipError) do
        rebuild_class :storage => :database, :column => 'missing'
      end
    end
  end

  context "An attachment with database storage and incorrect other style column name" do
    setup do
      rebuild_database_table_3_default_blob_columns
    end
    
    should "raise an exception" do
      assert_raises(Paperclip::PaperclipError) do
        rebuild_class :storage => :database,
          :styles => { 
            :medium => {:geometry => "300x300>", :column => 'missing'},
            :thumb => {:geometry => "100x100>"}
          }
      end
    end
  end

  context "An attachment with database storage and original style column name set to attachment name" do
    setup do
      rebuild_database_table_3_default_blob_columns
    end
    
    should "raise an exception" do
      assert_raises(Paperclip::PaperclipError) do
        rebuild_class :storage => :database, :column => 'avatar',
          :styles => { 
            :medium => {:geometry => "300x300>"},
            :thumb => {:geometry => "100x100>"}
          }
      end
    end
  end


  context "An attachment with database storage and other style column name set to attachment name" do
    setup do
      rebuild_database_table_3_default_blob_columns
    end
    
    should "raise an exception" do
      assert_raises(Paperclip::PaperclipError) do
        rebuild_class :storage => :database,
          :styles => { 
            :medium => {:geometry => "300x300>", :column => 'avatar'},
            :thumb => {:geometry => "100x100>"}
          }
      end
    end
  end


  context "An attachment with database storage" do
    setup do
      rebuild_database_table_3_custom_blob_columns
      rebuild_class :storage => :database, :column => 'avatar_file_data',
        :styles => { 
          :medium => {:geometry => "300x300>", :column => 'medium_file_data'},
          :thumb => {:geometry => "100x100>", :column => 'thumb_file_data'}
        }
      @dummy = Dummy.new
    end
    
    context "before assigned a file" do
      should "return false when asked exists?" do
        assert !@dummy.avatar.exists?
      end

      should "return its default_url" do
        assert @dummy.avatar.to_file.nil?
        assert_equal "/avatars/original/missing.png", @dummy.avatar.url
        assert_equal "/avatars/blah/missing.png", @dummy.avatar.url(:blah)
      end

      should "return nil as path" do
        assert @dummy.avatar.to_file.nil?
        assert_equal nil, @dummy.avatar.path
        assert_equal nil, @dummy.avatar.path(:blah)
      end
    end

    context "and assigned a file" do
      setup do
        @file = File.new(File.join(File.dirname(__FILE__),
                                   "fixtures",
                                   "5k.png"), 'rb')
        @contents = @file.read
        @file.rewind

        @dummy.avatar = @file
      end

      teardown { @file.close if @file }

      should "be dirty" do
        assert @dummy.avatar.dirty?
      end

      should "exist" do
        assert @dummy.avatar.exists?
      end

      should "save the actual file contents to the original style column" do
        assert_equal @contents, @dummy.avatar_file_data
        assert !(file = @dummy.avatar.to_file).nil?
        assert_equal Paperclip::Tempfile, file.class
        file.close
      end

      should "save some value to the other style columns" do
        assert !@dummy.medium_file_data.nil?
        assert !@dummy.thumb_file_data.nil?
      end

      should "return the proper default url" do
        assert_match %r{^/dummies/avatars/#{@dummy.id}\?style=original}, @dummy.avatar.url
        assert_match %r{^/dummies/avatars/#{@dummy.id}\?style=medium}, @dummy.avatar.url(:medium)
        assert_match %r{^/dummies/avatars/#{@dummy.id}\?style=thumb}, @dummy.avatar.url(:thumb)
      end

      should "return the column name as path" do
        assert_equal "avatar_file_data", @dummy.avatar.path
        assert_equal "avatar_file_data", @dummy.avatar.path(:original)
        assert_equal "medium_file_data", @dummy.avatar.path(:medium)
        assert_equal "thumb_file_data", @dummy.avatar.path(:thumb)
      end

      context "and assigned to another attachment" do
        setup do
          @dummy2 = Dummy.new
          @dummy2.avatar = @dummy.avatar
        end

        should "have the proper attributes assigned to the other attachment" do
          assert_equal @dummy.avatar_file_name, @dummy2.avatar_file_name
          assert_equal @dummy.avatar_content_type, @dummy2.avatar_content_type
          assert_equal @dummy.avatar_file_size, @dummy2.avatar_file_size
          assert_equal @dummy.avatar_file_data, @dummy2.avatar.file_contents
        end
      end

      context "and saved and assigned to another attachment" do
        setup do
          @dummy.save

          @dummy2 = Dummy.new
          @dummy2.avatar = @dummy.avatar
        end

        should "have the proper attributes assigned to the other attachment" do
          assert_equal @dummy.avatar_file_name, @dummy2.avatar_file_name
          assert_equal @dummy.avatar_content_type, @dummy2.avatar_content_type
          assert_equal @dummy.avatar_file_size, @dummy2.avatar_file_size
          assert_equal @dummy.avatar_file_data, @dummy2.avatar.file_contents
        end
      end

    end
  end
end
