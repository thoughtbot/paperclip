require './test/helper'

class FileSystemTest < Test::Unit::TestCase
  context "Filesystem" do
    context "normal file" do
      setup do
        rebuild_model :styles => { :thumbnail => "25x25#" }
        @dummy = Dummy.create!

        @file = File.open(fixture_file('5k.png'))
        @dummy.avatar = @file
      end

      teardown { @file.close }

      should "allow file assignment" do
        assert @dummy.save
      end

      should "store the original" do
        @dummy.save
        assert File.exists?(@dummy.avatar.path)
      end

      should "store the thumbnail" do
        @dummy.save
        assert File.exists?(@dummy.avatar.path(:thumbnail))
      end
    end

    context "with file that has space in file name" do
      setup do
        rebuild_model :styles => { :thumbnail => "25x25#" }
        @dummy = Dummy.create!

        @file = File.open(fixture_file('spaced file.png'))
        @dummy.avatar = @file
        @dummy.save
      end

      teardown { @file.close }

      should "store the file" do
        assert File.exists?(@dummy.avatar.path)
      end

      should "return a replaced version for path" do
        assert_match /.+\/spaced_file\.png/, @dummy.avatar.path
      end

      should "return a replaced version for url" do
        assert_match /.+\/spaced_file\.png/, @dummy.avatar.url
      end
    end
  end
end
