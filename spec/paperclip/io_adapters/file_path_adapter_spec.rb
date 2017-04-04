require 'spec_helper'

describe Paperclip::FilePathAdapter do
  context "a new instance" do
    context "with normal file" do
      before do
        @file_path = fixture_file("5k.png")
        @file = File.new(@file_path)
        @file.binmode
      end

      after do
        @file.close
        @subject.close if @subject
      end

      context 'comparing to original file' do
        before do
          @subject = Paperclip.io_adapters.for(@file_path)
        end

        it 'uses the original filename to generate the tempfile' do
          assert @subject.path.ends_with?(".png")
        end

        it "gets the right filename" do
          assert_equal "5k.png", @subject.original_filename
        end

        it "gets the content type" do
          assert_equal "image/png", @subject.content_type
        end

        it "gets the file's size" do
          assert_equal 4456, @subject.size
        end

        it "generates a MD5 hash of the contents" do
          expected = Digest::MD5.file(@file.path).to_s
          assert_equal expected, @subject.fingerprint
        end

        it "reads the contents of the file" do
          expected = @file.read
          assert expected.length > 0
          assert_equal expected, @subject.read
        end
      end
    end
  end
end
