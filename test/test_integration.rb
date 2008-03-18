require 'test/helper.rb'

class PaperclipTest < Test::Unit::TestCase
  context "A model with an attachment" do
    setup do
      rebuild_model :styles => { :large => "300x300>",
                                 :medium => "100x100",
                                 :thumb => ["32x32#", :gif] },
                    :default_style => :medium,
                    :url => "/:attachment/:class/:style/:id/:basename.:extension",
                    :path => ":rails_root/tmp/:attachment/:class/:style/:id/:basename.:extension"
    end

    should "integrate" do
      @dummy     = Dummy.new
      @file      = File.new(File.join(FIXTURES_DIR, "5k.png"))
      @bad_file  = File.new(File.join(FIXTURES_DIR, "bad.png"))

      assert @dummy.avatar = @file
      assert @dummy.valid?
      assert @dummy.save

      assert_equal "100x15", `identify -format "%wx%h" #{@dummy.avatar.to_io.path}`.chomp
      assert_equal "434x66", `identify -format "%wx%h" #{@dummy.avatar.to_io(:original).path}`.chomp
      assert_equal "300x46", `identify -format "%wx%h" #{@dummy.avatar.to_io(:large).path}`.chomp
      assert_equal "100x15", `identify -format "%wx%h" #{@dummy.avatar.to_io(:medium).path}`.chomp
      assert_equal "32x32",  `identify -format "%wx%h" #{@dummy.avatar.to_io(:thumb).path}`.chomp

      saved_paths = [:thumb, :medium, :large, :original].collect{|s| @dummy.avatar.to_io(s).path }

      @d2 = Dummy.find(@dummy.id)
      assert_equal "100x15", `identify -format "%wx%h" #{@dummy.avatar.to_io.path}`.chomp
      assert_equal "434x66", `identify -format "%wx%h" #{@dummy.avatar.to_io(:original).path}`.chomp
      assert_equal "300x46", `identify -format "%wx%h" #{@d2.avatar.to_io(:large).path}`.chomp
      assert_equal "100x15", `identify -format "%wx%h" #{@d2.avatar.to_io(:medium).path}`.chomp
      assert_equal "32x32",  `identify -format "%wx%h" #{@d2.avatar.to_io(:thumb).path}`.chomp

      @dummy.avatar = nil
      assert_nil @dummy.avatar_file_name
      assert @dummy.valid?
      assert @dummy.save

      saved_paths.each do |p|
        assert ! File.exists?(p)
      end

      @d2 = Dummy.find(@dummy.id)
      assert_nil @d2.avatar_file_name

      @d2.avatar = @bad_file
      assert ! @d2.valid?
      @d2.avatar = nil
      assert @d2.valid?

      Dummy.validates_attachment_presence :avatar
      @d3 = Dummy.find(@d2.id)
      @d3.avatar = @file
      assert   @d3.valid?
      @d3.avatar = @bad_file
      assert ! @d3.valid?
      @d3.avatar = nil
      assert ! @d3.valid?

      @dummy.avatar = @file
      assert @dummy.save
      @dummy.avatar = nil
      assert_nil @dummy.avatar_file_name
      @dummy.reload
      assert_equal "5k.png", @dummy.avatar_file_name
    end
  end
end

