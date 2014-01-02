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
            expected = <<-migration
              change_table :users do |t|
                t.attachment :avatar
              end
            migration

            assert_equal expected.squish, up.squish
          end

          assert_class_method :down, migration do |down|
            expected = <<-migration
              drop_attached_file :users, :avatar
            migration

            assert_equal expected.squish, down.squish
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
            expected = <<-migration
              change_table :users do |t|
                t.attachment :avatar
                t.attachment :photo
              end
            migration

            assert_equal expected.squish, up.squish
          end

          assert_class_method :down, migration do |down|
            expected = <<-migration
              drop_attached_file :users, :avatar
              drop_attached_file :users, :photo
            migration

            assert_equal expected.squish, down.squish
          end
        end
      end
    end

    context 'without required arguments' do
      should 'not create the migration' do
        begin
          silence_stream(STDERR) { run_generator %w() }
          assert_no_migration 'db/migrate/add_attachment_avatar_to_users.rb'
        rescue Thor::RequiredArgumentMissingError
          # This is also OK. It happens in 1.9.2 and Rails 3.2
        end
      end
    end
  end
end
