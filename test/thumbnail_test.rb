require './test/helper'

class ThumbnailTest < Test::Unit::TestCase

  context "A Paperclip Tempfile" do
    setup do
      @tempfile = Paperclip::Tempfile.new(["file", ".jpg"])
    end

    teardown { @tempfile.close }

    should "have its path contain a real extension" do
      assert_equal ".jpg", File.extname(@tempfile.path)
    end

    should "be a real Tempfile" do
      assert @tempfile.is_a?(::Tempfile)
    end
  end

  context "Another Paperclip Tempfile" do
    setup do
      @tempfile = Paperclip::Tempfile.new("file")
    end

    teardown { @tempfile.close }

    should "not have an extension if not given one" do
      assert_equal "", File.extname(@tempfile.path)
    end

    should "still be a real Tempfile" do
      assert @tempfile.is_a?(::Tempfile)
    end
  end

  context "An image" do
    setup do
      @file = File.new(fixture_file("5k.png"), 'rb')
    end

    teardown { @file.close }

    [["600x600>", "434x66"],
     ["400x400>", "400x61"],
     ["32x32<", "434x66"]
    ].each do |args|
      context "being thumbnailed with a geometry of #{args[0]}" do
        setup do
          @thumb = Paperclip::Thumbnail.new(@file, :geometry => args[0])
        end

        should "start with dimensions of 434x66" do
          cmd = %Q[identify -format "%wx%h" "#{@file.path}"]
          assert_equal "434x66", `#{cmd}`.chomp
        end

        should "report the correct target geometry" do
          assert_equal args[0], @thumb.target_geometry.to_s
        end

        context "when made" do
          setup do
            @thumb_result = @thumb.make
          end

          should "be the size we expect it to be" do
            cmd = %Q[identify -format "%wx%h" "#{@thumb_result.path}"]
            assert_equal args[1], `#{cmd}`.chomp
          end
        end
      end
    end

    context "being thumbnailed at 100x50 with cropping" do
      setup do
        @thumb = Paperclip::Thumbnail.new(@file, :geometry => "100x50#")
      end

      should "let us know when a command isn't found versus a processing error" do
        old_path = ENV['PATH']
        begin
          Cocaine::CommandLine.path = ''
          Paperclip.options[:command_path] = ''
          ENV['PATH'] = ''
          assert_raises(Paperclip::Errors::CommandNotFoundError) do
            silence_stream(STDERR) do
              @thumb.make
            end
          end
        ensure
          ENV['PATH'] = old_path
        end
      end

      should "report its correct current and target geometries" do
        assert_equal "100x50#", @thumb.target_geometry.to_s
        assert_equal "434x66", @thumb.current_geometry.to_s
      end

      should "report its correct format" do
        assert_nil @thumb.format
      end

      should "have whiny turned on by default" do
        assert @thumb.whiny
      end

      should "have convert_options set to nil by default" do
        assert_equal nil, @thumb.convert_options
      end

      should "have source_file_options set to nil by default" do
        assert_equal nil, @thumb.source_file_options
      end

      should "send the right command to convert when sent #make" do
        @thumb.expects(:convert).with do |*arg|
          arg[0] == ':source -auto-orient -resize "x50" -crop "100x50+114+0" +repage :dest' &&
          arg[1][:source] == "#{File.expand_path(@thumb.file.path)}[0]"
        end
        @thumb.make
      end

      should "create the thumbnail when sent #make" do
        dst = @thumb.make
        assert_match /100x50/, `identify "#{dst.path}"`
      end
    end

    context "being thumbnailed with source file options set" do
      setup do
        @thumb = Paperclip::Thumbnail.new(@file,
                                          :geometry            => "100x50#",
                                          :source_file_options => "-strip")
      end

      should "have source_file_options value set" do
        assert_equal ["-strip"], @thumb.source_file_options
      end

      should "send the right command to convert when sent #make" do
        @thumb.expects(:convert).with do |*arg|
          arg[0] == '-strip :source -auto-orient -resize "x50" -crop "100x50+114+0" +repage :dest' &&
          arg[1][:source] == "#{File.expand_path(@thumb.file.path)}[0]"
        end
        @thumb.make
      end

      should "create the thumbnail when sent #make" do
        dst = @thumb.make
        assert_match /100x50/, `identify "#{dst.path}"`
      end

      context "redefined to have bad source_file_options setting" do
        setup do
          @thumb = Paperclip::Thumbnail.new(@file,
                                            :geometry => "100x50#",
                                            :source_file_options => "-this-aint-no-option")
        end

        should "error when trying to create the thumbnail" do
          assert_raises(Paperclip::Error) do
            silence_stream(STDERR) do
              @thumb.make
            end
          end
        end
      end
    end

    context "being thumbnailed with convert options set" do
      setup do
        @thumb = Paperclip::Thumbnail.new(@file,
                                          :geometry        => "100x50#",
                                          :convert_options => "-strip -depth 8")
      end

      should "have convert_options value set" do
        assert_equal %w"-strip -depth 8", @thumb.convert_options
      end

      should "send the right command to convert when sent #make" do
        @thumb.expects(:convert).with do |*arg|
          arg[0] == ':source -auto-orient -resize "x50" -crop "100x50+114+0" +repage -strip -depth 8 :dest' &&
          arg[1][:source] == "#{File.expand_path(@thumb.file.path)}[0]"
        end
        @thumb.make
      end

      should "create the thumbnail when sent #make" do
        dst = @thumb.make
        assert_match /100x50/, `identify "#{dst.path}"`
      end

      context "redefined to have bad convert_options setting" do
        setup do
          @thumb = Paperclip::Thumbnail.new(@file,
                                            :geometry => "100x50#",
                                            :convert_options => "-this-aint-no-option")
        end

        should "error when trying to create the thumbnail" do
          assert_raises(Paperclip::Error) do
            silence_stream(STDERR) do
              @thumb.make
            end
          end
        end

        should "let us know when a command isn't found versus a processing error" do
          old_path = ENV['PATH']
          begin
            Cocaine::CommandLine.path = ''
            Paperclip.options[:command_path] = ''
            ENV['PATH'] = ''
            assert_raises(Paperclip::Errors::CommandNotFoundError) do
              silence_stream(STDERR) do
                @thumb.make
              end
            end
          ensure
            ENV['PATH'] = old_path
          end
        end
      end
    end

    context "being thumbnailed with a blank geometry string" do
      setup do
        @thumb = Paperclip::Thumbnail.new(@file,
                                          :geometry        => "",
                                          :convert_options => "-gravity center -crop \"300x300+0-0\"")
      end

      should "not get resized by default" do
        assert !@thumb.transformation_command.include?("-resize")
      end
    end

    context "being thumbnailed with default animated option (true)" do
      should "call identify to check for animated images when sent #make" do
        thumb = Paperclip::Thumbnail.new(@file, :geometry => "100x50#")
        thumb.expects(:identify).at_least_once.with do |*arg|
          arg[0] == '-format %m :file' &&
          arg[1][:file] == "#{File.expand_path(thumb.file.path)}[0]"
        end
        thumb.make
      end
    end

    context "passing a custom file geometry parser" do
      teardown do
        self.class.send(:remove_const, :GeoParser)
      end

      should "produce the appropriate transformation_command" do
        GeoParser = Class.new do
          def self.from_file(file)
            new
          end

          def transformation_to(target, should_crop)
            ["SCALE", "CROP"]
          end
        end

        thumb = Paperclip::Thumbnail.new(@file, :geometry => '50x50', :file_geometry_parser => GeoParser)

        transformation_command = thumb.transformation_command

        assert transformation_command.include?('-crop'),
          %{expected #{transformation_command.inspect} to include '-crop'}
        assert transformation_command.include?('"CROP"'),
          %{expected #{transformation_command.inspect} to include '"CROP"'}
        assert transformation_command.include?('-resize'),
          %{expected #{transformation_command.inspect} to include '-resize'}
        assert transformation_command.include?('"SCALE"'),
          %{expected #{transformation_command.inspect} to include '"SCALE"'}
      end
    end

    context "passing a custom geometry string parser" do
      teardown do
        self.class.send(:remove_const, :GeoParser)
      end

      should "produce the appropriate transformation_command" do
        GeoParser = Class.new do
          def self.parse(s)
            new
          end

          def to_s
            "151x167"
          end
        end

        thumb = Paperclip::Thumbnail.new(@file, :geometry => '50x50', :string_geometry_parser => GeoParser)

        transformation_command = thumb.transformation_command

        assert transformation_command.include?('"151x167"'),
          %{expected #{transformation_command.inspect} to include '151x167'}
      end
    end
  end

  context "An image with exif orientation" do
    setup do
      @file = File.new(fixture_file("rotated.jpg"), 'rb')
    end

    teardown { @file.close }

    context "With :auto_orient => false" do
      setup do
        @thumb = Paperclip::Thumbnail.new(@file, :geometry => "100x50", :auto_orient => false)
      end

      should "send the right command to convert when sent #make" do
        @thumb.expects(:convert).with do |*arg|
          arg[0] == ':source -resize "100x50" :dest' &&
              arg[1][:source] == "#{File.expand_path(@thumb.file.path)}[0]"
        end
        @thumb.make
      end

      should "create the thumbnail when sent #make" do
        dst = @thumb.make
        assert_match /75x50/, `identify "#{dst.path}"`
      end

      should "not touch the orientation information" do
        dst = @thumb.make
        assert_match /exif:Orientation=6/, `identify -format "%[EXIF:*]" "#{dst.path}"`
      end
    end

    context "Without :auto_orient => false" do
      setup do
        @thumb = Paperclip::Thumbnail.new(@file, :geometry => "100x50")
      end

      should "send the right command to convert when sent #make" do
        @thumb.expects(:convert).with do |*arg|
          arg[0] == ':source -auto-orient -resize "100x50" :dest' &&
              arg[1][:source] == "#{File.expand_path(@thumb.file.path)}[0]"
        end
        @thumb.make
      end

      should "create the thumbnail when sent #make" do
        dst = @thumb.make
        assert_match /33x50/, `identify "#{dst.path}"`
      end

      should "remove the orientation information" do
        dst = @thumb.make
        assert_match /exif:Orientation=1/, `identify -format "%[EXIF:*]" "#{dst.path}"`
      end
    end
  end

  context "A multipage PDF" do
    setup do
      @file = File.new(fixture_file("twopage.pdf"), 'rb')
    end

    teardown { @file.close }

    should "start with two pages with dimensions 612x792" do
      cmd = %Q[identify -format "%wx%h" "#{@file.path}"]
      assert_equal "612x792"*2, `#{cmd}`.chomp
    end

    context "being thumbnailed at 100x100 with cropping" do
      setup do
        @thumb = Paperclip::Thumbnail.new(@file, :geometry => "100x100#", :format => :png)
      end

      should "report its correct current and target geometries" do
        assert_equal "100x100#", @thumb.target_geometry.to_s
        assert_equal "612x792", @thumb.current_geometry.to_s
      end

      should "report its correct format" do
        assert_equal :png, @thumb.format
      end

      should "create the thumbnail when sent #make" do
        dst = @thumb.make
        assert_match /100x100/, `identify "#{dst.path}"`
      end
    end
  end

  context "An animated gif" do
    setup do
      @file = File.new(fixture_file("animated.gif"), 'rb')
    end

    teardown { @file.close }

    should "start with 12 frames with size 100x100" do
      cmd = %Q[identify -format "%wx%h" "#{@file.path}"]
      assert_equal "100x100"*12, `#{cmd}`.chomp
    end

    context "with static output" do
      setup do
       @thumb = Paperclip::Thumbnail.new(@file, :geometry => "50x50", :format => :jpg)
      end

      should "create the single frame thumbnail when sent #make" do
        dst = @thumb.make
        cmd = %Q[identify -format "%wx%h" "#{dst.path}"]
        assert_equal "50x50", `#{cmd}`.chomp
      end
    end

    context "with animated output format" do
      setup do
       @thumb = Paperclip::Thumbnail.new(@file, :geometry => "50x50", :format => :gif)
      end

      should "create the 12 frames thumbnail when sent #make" do
        dst = @thumb.make
        cmd = %Q[identify -format "%wx%h" "#{dst.path}"]
        assert_equal "50x50"*12, `#{cmd}`.chomp
      end

      should "use the -coalesce option" do
        assert_equal @thumb.transformation_command.first, "-coalesce"
      end
    end

    context "with omitted output format" do
      setup do
       @thumb = Paperclip::Thumbnail.new(@file, :geometry => "50x50")
      end

      should "create the 12 frames thumbnail when sent #make" do
        dst = @thumb.make
        cmd = %Q[identify -format "%wx%h" "#{dst.path}"]
        assert_equal "50x50"*12, `#{cmd}`.chomp
      end

      should "use the -coalesce option" do
        assert_equal @thumb.transformation_command.first, "-coalesce"
      end
    end

    context "with unidentified source format" do
      setup do
        @unidentified_file = File.new(fixture_file("animated.unknown"), 'rb')
        @thumb = Paperclip::Thumbnail.new(@file, :geometry => "60x60")
      end

      should "create the 12 frames thumbnail when sent #make" do
        dst = @thumb.make
        cmd = %Q[identify -format "%wx%h" "#{dst.path}"]
        assert_equal "60x60"*12, `#{cmd}`.chomp
      end

      should "use the -coalesce option" do
        assert_equal @thumb.transformation_command.first, "-coalesce"
      end
    end

    context "with no source format" do
      setup do
        @unidentified_file = File.new(fixture_file("animated"), 'rb')
        @thumb = Paperclip::Thumbnail.new(@file, :geometry => "70x70")
      end

      should "create the 12 frames thumbnail when sent #make" do
        dst = @thumb.make
        cmd = %Q[identify -format "%wx%h" "#{dst.path}"]
        assert_equal "70x70"*12, `#{cmd}`.chomp
      end

      should "use the -coalesce option" do
        assert_equal @thumb.transformation_command.first, "-coalesce"
      end
    end

    context "with animated option set to false" do
      setup do
       @thumb = Paperclip::Thumbnail.new(@file, :geometry => "50x50", :animated => false)
      end

      should "output the gif format" do
        dst = @thumb.make
        cmd = %Q[identify "#{dst.path}"]
        assert_match /GIF/, `#{cmd}`.chomp
      end

      should "create the single frame thumbnail when sent #make" do
        dst = @thumb.make
        cmd = %Q[identify -format "%wx%h" "#{dst.path}"]
        assert_equal "50x50", `#{cmd}`.chomp
      end
    end
  end
end
