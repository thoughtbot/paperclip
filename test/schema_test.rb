require './test/helper'
require 'paperclip/schema'
require 'active_support/testing/deprecation'

class SchemaTest < Test::Unit::TestCase
  include ActiveSupport::Testing::Deprecation

  def setup
    rebuild_class
  end

  def teardown
    Dummy.connection.drop_table :dummies rescue nil
  end

  context "within table definition" do
    context "using #has_attached_file" do
      setup do
        ActiveSupport::Deprecation.silenced = false
      end
      should "create attachment columns" do
        Dummy.connection.create_table :dummies, :force => true do |t|
          ActiveSupport::Deprecation.silence do
            t.has_attached_file :avatar
          end
        end
        rebuild_class

        columns = Dummy.columns.map{ |column| [column.name, column.type] }

        assert_includes columns, ['avatar_file_name', :string]
        assert_includes columns, ['avatar_content_type', :string]
        assert_includes columns, ['avatar_file_size', :integer]
        assert_includes columns, ['avatar_updated_at', :datetime]
      end

      should "display deprecation warning" do
        Dummy.connection.create_table :dummies, :force => true do |t|
          assert_deprecated do
            t.has_attached_file :avatar
          end
        end
      end
    end

    context "using #attachment" do
      setup do
        Dummy.connection.create_table :dummies, :force => true do |t|
          t.attachment :avatar
        end
        rebuild_class
      end

      should "create attachment columns" do
        columns = Dummy.columns.map{ |column| [column.name, column.type] }

        assert_includes columns, ['avatar_file_name', :string]
        assert_includes columns, ['avatar_content_type', :string]
        assert_includes columns, ['avatar_file_size', :integer]
        assert_includes columns, ['avatar_updated_at', :datetime]
      end
    end
  end

  context "within schema statement" do
    setup do
      Dummy.connection.create_table :dummies, :force => true
    end

    context "migrating up" do
      context "with single attachment" do
        setup do
          Dummy.connection.add_attachment :dummies, :avatar
          rebuild_class
        end

        should "create attachment columns" do
          columns = Dummy.columns.map{ |column| [column.name, column.type] }

          assert_includes columns, ['avatar_file_name', :string]
          assert_includes columns, ['avatar_content_type', :string]
          assert_includes columns, ['avatar_file_size', :integer]
          assert_includes columns, ['avatar_updated_at', :datetime]
        end
      end

      context "with multiple attachments" do
        setup do
          Dummy.connection.add_attachment :dummies, :avatar, :photo
          rebuild_class
        end

        should "create attachment columns" do
          columns = Dummy.columns.map{ |column| [column.name, column.type] }

          assert_includes columns, ['avatar_file_name', :string]
          assert_includes columns, ['avatar_content_type', :string]
          assert_includes columns, ['avatar_file_size', :integer]
          assert_includes columns, ['avatar_updated_at', :datetime]
          assert_includes columns, ['photo_file_name', :string]
          assert_includes columns, ['photo_content_type', :string]
          assert_includes columns, ['photo_file_size', :integer]
          assert_includes columns, ['photo_updated_at', :datetime]
        end
      end

      context "with no attachment" do
        should "raise an error" do
          assert_raise ArgumentError do
            Dummy.connection.add_attachment :dummies
          rebuild_class
          end
        end
      end
    end

    context "migrating down" do
      setup do
        Dummy.connection.change_table :dummies do |t|
          t.column :avatar_file_name, :string
          t.column :avatar_content_type, :string
          t.column :avatar_file_size, :integer
          t.column :avatar_updated_at, :datetime
        end
      end

      context "using #drop_attached_file" do
        setup do
          ActiveSupport::Deprecation.silenced = false
        end
        should "remove the attachment columns" do
          ActiveSupport::Deprecation.silence do
            Dummy.connection.drop_attached_file :dummies, :avatar
          end
          rebuild_class

          columns = Dummy.columns.map{ |column| [column.name, column.type] }

          assert_not_includes columns, ['avatar_file_name', :string]
          assert_not_includes columns, ['avatar_content_type', :string]
          assert_not_includes columns, ['avatar_file_size', :integer]
          assert_not_includes columns, ['avatar_updated_at', :datetime]
        end

        should "display a deprecation warning" do
          assert_deprecated do
            Dummy.connection.drop_attached_file :dummies, :avatar
          end
        end
      end

      context "using #remove_attachment" do
        context "with single attachment" do
          setup do
            Dummy.connection.remove_attachment :dummies, :avatar
            rebuild_class
          end

          should "remove the attachment columns" do
            columns = Dummy.columns.map{ |column| [column.name, column.type] }

            assert_not_includes columns, ['avatar_file_name', :string]
            assert_not_includes columns, ['avatar_content_type', :string]
            assert_not_includes columns, ['avatar_file_size', :integer]
            assert_not_includes columns, ['avatar_updated_at', :datetime]
          end
        end

        context "with multiple attachments" do
          setup do
            Dummy.connection.change_table :dummies do |t|
              t.column :photo_file_name, :string
              t.column :photo_content_type, :string
              t.column :photo_file_size, :integer
              t.column :photo_updated_at, :datetime
            end

            Dummy.connection.remove_attachment :dummies, :avatar, :photo
            rebuild_class
          end

          should "remove the attachment columns" do
            columns = Dummy.columns.map{ |column| [column.name, column.type] }

            assert_not_includes columns, ['avatar_file_name', :string]
            assert_not_includes columns, ['avatar_content_type', :string]
            assert_not_includes columns, ['avatar_file_size', :integer]
            assert_not_includes columns, ['avatar_updated_at', :datetime]
            assert_not_includes columns, ['photo_file_name', :string]
            assert_not_includes columns, ['photo_content_type', :string]
            assert_not_includes columns, ['photo_file_size', :integer]
            assert_not_includes columns, ['photo_updated_at', :datetime]
          end
        end

        context "with no attachment" do
          should "raise an error" do
            assert_raise ArgumentError do
              Dummy.connection.remove_attachment :dummies
            end
          end
        end
      end
    end
  end
end
