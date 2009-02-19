require 'test/helper'

def rebuild_database_storage_model options = {}
  ActiveRecord::Base.connection.create_table :dummy_files, :force => true do |table|
    table.column :style, :string
    table.column :dummy_id, :integer
  end
  ActiveRecord::Base.connection.execute 'ALTER TABLE dummy_files ADD COLUMN file_contents LONGBLOB'
  Object.send(:remove_const, "DummyFile") rescue nil
  Object.const_set("DummyFile", Class.new(ActiveRecord::Base))
  rebuild_model options
end

class DatabaseStorageTest < Test::Unit::TestCase

  context "An attachment with database storage and default options" do
    setup do
      rebuild_database_storage_model :storage => :database
    end

    should "be extended by the database module" do
      assert Dummy.new.avatar.is_a?(Paperclip::Storage::Database)
    end

    should "not be extended by the S3 module" do
      assert ! Dummy.new.avatar.is_a?(Paperclip::Storage::S3)
    end

    should "not be extended by the Filesystem module" do
      assert ! Dummy.new.avatar.is_a?(Paperclip::Storage::Filesystem)
    end
    
    context "when assigned without default storage table" do
      setup do
        @file = File.new(File.join(File.dirname(__FILE__), 'fixtures', '5k.png'), 'rb')
        @dummy = Dummy.new
        @dummy.avatar = @file
      end
      
      teardown { @file.close }

      should "expect the default table name" do
        assert_equal 'avatars', @dummy.avatar.database_table
      end

      should "fail with missing database table error" do # ... since "dummies" table is not created by rebuild_database_storage_model
        assert_raises(ActiveRecord::StatementInvalid){ @dummy.save }
      end
    end
  end

  context "An attachment with database storage and proper database specified" do
    setup do
      rebuild_database_storage_model :storage => :database, :database_table => 'dummy_files'
      @dummy = Dummy.new
    end

    should "not exist before a file is assigned" do
      assert !@dummy.avatar.exists?
    end

    context "when assigned" do
      setup do
        @file = File.new(File.join(File.dirname(__FILE__), 'fixtures', '5k.png'), 'rb')
        @dummy.avatar = @file
        ActionController::Base.stubs(:relative_url_root).returns("/base")
      end

      teardown { @file.close }

      context "correct paperclip_files model" do
        setup do
          assert_nothing_raised do
            @paperclip_file = DummyAvatarPaperclipFile.new
          end
        end

        should "exist" do
          assert @paperclip_file.is_a?(ActiveRecord::Base)
        end

        should "have correct table name" do
          assert_equal 'dummy_files', DummyAvatarPaperclipFile.table_name
        end
      end
      
      should "initially have new record path" do
        default_style = @dummy.avatar.default_style
        assert_equal "dummy_files(id=new,style=#{default_style.to_s})", @dummy.avatar.path(default_style)
      end
      
      should "have the correct url" do
        assert_match %r{^/base/dummies/avatars/#{@dummy.id}\?style=original}, @dummy.avatar.url
      end
      
      should "return a Tempfile when sent #to_io" do
        assert_equal Tempfile, @dummy.avatar.to_io.class
      end
      
      context "and saved" do
        setup do
          @dummy.save
        end
      
        should "exist" do
          assert @dummy.avatar.exists?
        end

        should "should have database path with id" do
          default_style = @dummy.avatar.default_style
          assert_match %r{dummy_files\(id=[0-9]+,style=#{default_style.to_s}\)}, @dummy.avatar.path(default_style)
        end
      
        should_change "DummyFile.count", :by => 1
      
        context "a new record in the files table" do
          setup do
            @dummy_db_file = @dummy.dummy_avatar_paperclip_files.first
          end
      
          should "should exist" do
            assert_not_nil @dummy_db_file
          end
          
          should "contain the proper file contents" do
            @file.rewind
            assert_equal @file.read, @dummy.avatar.file_contents('original')
          end

          context "and removed" do
            setup do
              @dummy.destroy_attached_files
            end
      
            should_change "DummyFile.count", :by => -1

            should "should leave empty file list in model" do
              assert_equal 0, @dummy.dummy_avatar_paperclip_files.count
            end

          end
        end
      end
    end
  end

  context "An attachment with four styles" do
    setup do
      rebuild_database_storage_model :styles => {
                                        :small => "50x50",
                                        :thumb => "100x100",
                                        :large => "400x400"
                                      },
                                      :storage => :database,
                                      :database_table => 'dummy_files'
    end

    context "when assigned" do
      setup do
        @file = File.new(File.join(File.dirname(__FILE__), 'fixtures', '5k.png'), 'rb')
        @dummy = Dummy.new
        @dummy.avatar = @file
        ActionController::Base.stubs(:relative_url_root).returns("/base")
      end

      teardown { @file.close }

      should "initially have new record path for each style" do
        [:large, :thumb, :small, :original].each do |style|
          assert_equal "dummy_files(id=new,style=#{style.to_s})", @dummy.avatar.path(style)
        end
      end
      
      should "have the correct url for each style" do
        [:large, :thumb, :small, :original].each do |style|
          assert_match %r{^/base/dummies/avatars/#{@dummy.id}\?style=#{style}}, @dummy.avatar.url(style)
        end
      end
      
      context "and saved" do
        setup do
          @dummy.save
        end
      
        should "should have database path with id" do
          [:large, :thumb, :small, :original].each do |style|
            assert_match %r{dummy_files\(id=[0-9]+,style=#{style.to_s}\)}, @dummy.avatar.path(style)
          end
        end
      
        should_change "DummyFile.count", :by => 4
      
        context "four new records in the files table" do
          setup do
            @dummy_db_files = @dummy.dummy_avatar_paperclip_files
          end
      
          should "should exist" do
            [:large, :thumb, :small, :original].each do |style|
              assert_not_nil @dummy.avatar.file_for(style)
            end
          end
          
          should "contain the proper file contents for the original file" do
            @file.rewind
            assert_equal @file.read, @dummy.avatar.file_contents('original')
          end
      
          should "contain some file contents for the custom styles" do
            [:large, :thumb, :small].each do |style|
              assert_not_nil @dummy.avatar.file_contents(style)
            end
          end

          context "and removed" do
            setup do
              @dummy.destroy_attached_files
            end
      
            should_change "DummyFile.count", :by => -4
      
            should "should leave empty file list in model" do
              assert_equal 0, @dummy.dummy_avatar_paperclip_files.count
            end
      
          end
        end
      end
    end
  end

  context "An attachment that is assigned with another saved attachment" do
    setup do
      rebuild_database_storage_model :storage => :database, :database_table => 'dummy_files'
      @dummy = Dummy.new
      @dummy2 = Dummy.new
      @file = File.new(File.join(File.dirname(__FILE__), 'fixtures', '5k.png'), 'rb')
      @dummy.avatar = @file
      @dummy.avatar.save
      @dummy2.avatar = @dummy.avatar
    end
        
    should "have the proper attributes" do
      assert_equal @dummy.avatar_file_name, @dummy2.avatar_file_name
      assert_equal @dummy.avatar_content_type, @dummy2.avatar_content_type
      assert_equal @dummy.avatar_file_size, @dummy2.avatar_file_size
    end
  end

end
