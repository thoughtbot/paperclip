require 'test/helper.rb'

class IntegrationTest < Test::Unit::TestCase
  context "Many models at once" do
    setup do
      rebuild_model
      @file      = File.new(File.join(FIXTURES_DIR, "5k.png"))
      300.times do |i|
        Dummy.create! :avatar => @file
      end
    end
    
    should "not exceed the open file limit" do
       assert_nothing_raised do
         dummies = Dummy.find(:all)
         dummies.each { |dummy| dummy.avatar }
       end
    end
  end
  
  context "A model with a filesystem attachment" do
    setup do
      rebuild_model :styles => { :large => "300x300>",
                                 :medium => "100x100",
                                 :thumb => ["32x32#", :gif] },
                    :default_style => :medium,
                    :url => "/:attachment/:class/:style/:id/:basename.:extension",
                    :path => ":rails_root/tmp/:attachment/:class/:style/:id/:basename.:extension"
      @dummy     = Dummy.new
      @file      = File.new(File.join(FIXTURES_DIR, "5k.png"))
      @bad_file  = File.new(File.join(FIXTURES_DIR, "bad.png"))

      assert @dummy.avatar = @file
      assert @dummy.valid?
      assert @dummy.save
    end

    should "write and delete its files" do
      [["434x66", :original],
       ["300x46", :large],
       ["100x15", :medium],
       ["32x32", :thumb]].each do |geo, style|
        cmd = %Q[identify -format "%wx%h" #{@dummy.avatar.to_file(style).path}]
        assert_equal geo, `#{cmd}`.chomp, cmd
      end

      saved_paths = [:thumb, :medium, :large, :original].collect{|s| @dummy.avatar.to_file(s).path }

      @d2 = Dummy.find(@dummy.id)
      assert_equal "100x15", `identify -format "%wx%h" #{@d2.avatar.to_file.path}`.chomp
      assert_equal "434x66", `identify -format "%wx%h" #{@d2.avatar.to_file(:original).path}`.chomp
      assert_equal "300x46", `identify -format "%wx%h" #{@d2.avatar.to_file(:large).path}`.chomp
      assert_equal "100x15", `identify -format "%wx%h" #{@d2.avatar.to_file(:medium).path}`.chomp
      assert_equal "32x32",  `identify -format "%wx%h" #{@d2.avatar.to_file(:thumb).path}`.chomp

      @dummy.avatar = "not a valid file but not nil"
      assert_equal File.basename(@file.path), @dummy.avatar_file_name
      assert @dummy.valid?
      assert @dummy.save

      saved_paths.each do |p|
        assert File.exists?(p)
      end

      @dummy.avatar = nil
      assert_nil @dummy.avatar_file_name
      assert @dummy.valid?
      assert @dummy.save

      saved_paths.each do |p|
        assert ! File.exists?(p)
      end

      @d2 = Dummy.find(@dummy.id)
      assert_nil @d2.avatar_file_name
    end

    should "work exactly the same when new as when reloaded" do
      @d2 = Dummy.find(@dummy.id)

      assert_equal @dummy.avatar_file_name, @d2.avatar_file_name
      [:thumb, :medium, :large, :original].each do |style|
        assert_equal @dummy.avatar.to_file(style).path, @d2.avatar.to_file(style).path
      end

      saved_paths = [:thumb, :medium, :large, :original].collect{|s| @dummy.avatar.to_file(s).path }

      @d2.avatar = nil
      assert @d2.save

      saved_paths.each do |p|
        assert ! File.exists?(p)
      end
    end

    should "know the difference between good files, bad files, not files, and nil" do
      expected = @dummy.avatar.to_file
      @dummy.avatar = "not a file"
      assert @dummy.valid?
      assert_equal expected.path, @dummy.avatar.to_file.path

      @dummy.avatar = @bad_file
      assert ! @dummy.valid?
      @dummy.avatar = nil
      assert @dummy.valid?

      Dummy.validates_attachment_presence :avatar
      @d2 = Dummy.find(@dummy.id)
      @d2.avatar = @file
      assert   @d2.valid?
      @d2.avatar = @bad_file
      assert ! @d2.valid?
      @d2.avatar = nil
      assert ! @d2.valid?
    end

    should "be able to reload without saving an not have the file disappear" do
      @dummy.avatar = @file
      assert @dummy.save
      @dummy.avatar = nil
      assert_nil @dummy.avatar_file_name
      @dummy.reload
      assert_equal "5k.png", @dummy.avatar_file_name
    end
  end

  if ENV['S3_TEST_BUCKET']
    def s3_files_for attachment
      [:thumb, :medium, :large, :original].inject({}) do |files, style|
        data = `curl '#{attachment.url(style)}' 2>/dev/null`.chomp
        t = Tempfile.new("paperclip-test")
        t.write(data)
        t.rewind
        files[style] = t
        files
      end
    end

    context "A model with an S3 attachment" do
      setup do
        rebuild_model :styles => { :large => "300x300>",
                                   :medium => "100x100",
                                   :thumb => ["32x32#", :gif] },
                      :storage => :s3,
                      # :s3_options => {:logger => Logger.new(StringIO.new)},
                      :s3_credentials => File.new(File.join(File.dirname(__FILE__), "s3.yml")),
                      :default_style => :medium,
                      :bucket => ENV['S3_TEST_BUCKET'],
                      :path => ":class/:attachment/:id/:style/:basename.:extension"
        @dummy     = Dummy.new
        @file      = File.new(File.join(FIXTURES_DIR, "5k.png"))
        @bad_file  = File.new(File.join(FIXTURES_DIR, "bad.png"))

        assert @dummy.avatar = @file
        assert @dummy.valid?
        assert @dummy.save

        @files_on_s3 = s3_files_for @dummy.avatar
      end

      should "write and delete its files" do
        [["434x66", :original],
         ["300x46", :large],
         ["100x15", :medium],
         ["32x32", :thumb]].each do |geo, style|
          cmd = %Q[identify -format "%wx%h" #{@files_on_s3[style].path}]
          assert_equal geo, `#{cmd}`.chomp, cmd
        end

        @d2 = Dummy.find(@dummy.id)
        @d2_files = s3_files_for @d2.avatar
        [["434x66", :original],
         ["300x46", :large],
         ["100x15", :medium],
         ["32x32", :thumb]].each do |geo, style|
          cmd = %Q[identify -format "%wx%h" #{@d2_files[style].path}]
          assert_equal geo, `#{cmd}`.chomp, cmd
        end

        @dummy.avatar = "not a valid file but not nil"
        assert_equal File.basename(@file.path), @dummy.avatar_file_name
        assert @dummy.valid?
        assert @dummy.save

        saved_keys = [:thumb, :medium, :large, :original].collect{|s| @dummy.avatar.to_file(s) }

        saved_keys.each do |key|
          assert key.exists?
        end

        @dummy.avatar = nil
        assert_nil @dummy.avatar_file_name
        assert @dummy.valid?
        assert @dummy.save

        saved_keys.each do |key|
          assert ! key.exists?
        end

        @d2 = Dummy.find(@dummy.id)
        assert_nil @d2.avatar_file_name
      end

      should "work exactly the same when new as when reloaded" do
        @d2 = Dummy.find(@dummy.id)

        assert_equal @dummy.avatar_file_name, @d2.avatar_file_name
        [:thumb, :medium, :large, :original].each do |style|
          assert_equal @dummy.avatar.to_file(style).to_s, @d2.avatar.to_file(style).to_s
        end

        saved_keys = [:thumb, :medium, :large, :original].collect{|s| @dummy.avatar.to_file(s) }

        @d2.avatar = nil
        assert @d2.save

        saved_keys.each do |key|
          assert ! key.exists?
        end
      end

      should "know the difference between good files, bad files, not files, and nil" do
        expected = @dummy.avatar.to_file
        @dummy.avatar = "not a file"
        assert @dummy.valid?
        assert_equal expected.full_name, @dummy.avatar.to_file.full_name

        @dummy.avatar = @bad_file
        assert ! @dummy.valid?
        @dummy.avatar = nil
        assert @dummy.valid?

        Dummy.validates_attachment_presence :avatar
        @d2 = Dummy.find(@dummy.id)
        @d2.avatar = @file
        assert   @d2.valid?
        @d2.avatar = @bad_file
        assert ! @d2.valid?
        @d2.avatar = nil
        assert ! @d2.valid?
      end

      should "be able to reload without saving an not have the file disappear" do
        @dummy.avatar = @file
        assert @dummy.save
        @dummy.avatar = nil
        assert_nil @dummy.avatar_file_name
        @dummy.reload
        assert_equal "5k.png", @dummy.avatar_file_name
      end
    end
  end
end

