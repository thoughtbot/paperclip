require 'helper'

class FileSystemTest < Test::Unit::TestCase
  context "Filesystem" do
    setup do
      rebuild_model :styles => { :thumbnail => "25x25#" }
      @dummy = Dummy.create!

      @dummy.avatar = File.open(File.join(File.dirname(__FILE__), "..", "fixtures", "5k.png"))
    end

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

    should "clean up file objects" do
      File.stubs(:exist?).returns(true)
      Paperclip::Tempfile.any_instance.expects(:close).at_least_once()
      Paperclip::Tempfile.any_instance.expects(:unlink).at_least_once()

      @dummy.save!
    end
  end
end
