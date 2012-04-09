require './test/helper'
require 'rails/generators'
require 'generators/paperclip/paperclip_generator'

class GeneratorTest < Rails::Generators::TestCase
  tests PaperclipGenerator
  destination File.expand_path("../tmp", File.dirname(__FILE__))
  setup :prepare_destination

  context 'running migration' do
    context 'with single attachment name' do
      setup do
        run_generator %w(user avatar)
      end

      should 'create a correct migration file' do
        assert_migration 'db/migrate/add_attachment_avatar_to_users.rb' do |migration|
          assert_match /class AddAttachmentAvatarToUsers/, migration

          assert_class_method :up, migration do |up|
            assert_match /add_column :users, :avatar_file_name, :string/, up
            assert_match /add_column :users, :avatar_content_type, :string/, up
            assert_match /add_column :users, :avatar_file_size, :integer/, up
            assert_match /add_column :users, :avatar_updated_at, :datetime/, up
          end

          assert_class_method :down, migration do |down|
            assert_match /remove_column :users, :avatar_file_name/, down
            assert_match /remove_column :users, :avatar_content_type/, down
            assert_match /remove_column :users, :avatar_file_size/, down
            assert_match /remove_column :users, :avatar_updated_at/, down
          end
        end
      end
    end

    context 'with multiple attachment names' do
      setup do
        run_generator %w(user avatar photo)
      end

      should 'create a correct migration file' do
        assert_migration 'db/migrate/add_attachment_avatar_photo_to_users.rb' do |migration|
          assert_match /class AddAttachmentAvatarPhotoToUsers/, migration

          assert_class_method :up, migration do |up|
            assert_match /add_column :users, :avatar_file_name, :string/, up
            assert_match /add_column :users, :avatar_content_type, :string/, up
            assert_match /add_column :users, :avatar_file_size, :integer/, up
            assert_match /add_column :users, :avatar_updated_at, :datetime/, up
            assert_match /add_column :users, :photo_file_name, :string/, up
            assert_match /add_column :users, :photo_content_type, :string/, up
            assert_match /add_column :users, :photo_file_size, :integer/, up
            assert_match /add_column :users, :photo_updated_at, :datetime/, up
          end

          assert_class_method :down, migration do |down|
            assert_match /remove_column :users, :avatar_file_name/, down
            assert_match /remove_column :users, :avatar_content_type/, down
            assert_match /remove_column :users, :avatar_file_size/, down
            assert_match /remove_column :users, :avatar_updated_at/, down
            assert_match /remove_column :users, :photo_file_name/, down
            assert_match /remove_column :users, :photo_content_type/, down
            assert_match /remove_column :users, :photo_file_size/, down
            assert_match /remove_column :users, :photo_updated_at/, down
          end
        end
      end
    end

    context 'without required arguments' do
      should 'not create the migration' do
        silence_stream(STDERR) { run_generator %w() }
        assert_no_migration 'db/migrate/add_attachment_avatar_to_users.rb'
      end
    end
  end
end
