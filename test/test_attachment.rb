require 'test/helper'

class Dummy
  # This is a dummy class
end

class AttachmentTest < Test::Unit::TestCase
  context "An attachment" do
    setup do
      @default_options = {
        :path => ":rails_root/tmp/:attachment/:class/:style/:id/:basename.:extension"
      }
      @instance = stub
      @instance.stubs(:id).returns(41)
      @instance.stubs(:class).returns(Dummy)
      @instance.stubs(:[]).with(:test_file_name).returns("5k.png")
      @instance.stubs(:[]).with(:test_content_type).returns("image/png")
      @instance.stubs(:[]).with(:test_file_size).returns(12345)
      @attachment = Paperclip::Attachment.new(:test, @instance, @default_options)
      @file = File.new(File.join(File.dirname(__FILE__), "fixtures", "5k.png"))
    end

    context "when expecting three styles" do
      setup do
        @attachment = Paperclip::Attachment.new(:test, @instance, @default_options.merge({
          :styles => { :large  => ["400x400", :png],
                       :medium => ["100x100", :gif],
                       :small => ["32x32#", :jpg]}
        }))
      end

      context "and assigned a file" do
        setup do
          @instance.expects(:[]=).with(:test_file_name, File.basename(@file.path))
          @instance.expects(:[]=).with(:test_content_type, "image/png")
          @instance.expects(:[]=).with(:test_file_size, @file.size)
          @instance.expects(:[]=).with(:test_file_name, nil)
          @instance.expects(:[]=).with(:test_content_type, nil)
          @instance.expects(:[]=).with(:test_file_size, nil)
          @attachment.assign(@file)
        end

        should "be dirty" do
          assert @attachment.dirty?
        end

        should "have its image and attachments as tempfiles" do
          [nil, :large, :medium, :small].each do |style|
            assert File.exists?(@attachment.to_io(style))
          end
        end

        context "and saved" do
          setup do
            @attachment.save
          end

          should "commit the files to disk" do
            [nil, :large, :medium, :small].each do |style|
              io = @attachment.to_io(style)
              assert File.exists?(io)
              assert ! io.is_a?(::Tempfile)
            end
          end

          should "save the files as the right formats and sizes" do
            [[:large, 400, 61, "PNG"], [:medium, 100, 15, "GIF"], [:small, 32, 32, "JPEG"]].each do |style|
              out = `identify -format "%w %h %b %m" #{@attachment.to_io(style.first).path}`
              width, height, size, format = out.split(" ")
              assert_equal style[1].to_s, width.to_s 
              assert_equal style[2].to_s, height.to_s
              assert_equal style[3].to_s, format.to_s
            end
          end
        end
      end
    end
  end
end
