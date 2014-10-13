require 'spec_helper'

describe Paperclip::HashieMashAdapter do
  context "a new instance" do
    context "with normal file" do
      before do
        tempfile = File.new(fixture_file("5k.png"))
        tempfile.binmode
        module Hashie
          class Mash < OpenStruct; end
        end
        @file = Hashie::Mash.new(
          filename: "5k.png",
          type: 'image/png',
          tempfile: tempfile
        )
      end

      context 'doing normal things' do
        before do
          @subject = Paperclip.io_adapters.for(@file)
        end

        it 'uses the original filename to generate the tempfile' do
          assert @subject.path.ends_with?(".png")
        end

        it "gets the right filename" do
          assert_equal "5k.png", @subject.original_filename
        end

        it "forces binmode on tempfile" do
          assert @subject.instance_variable_get("@tempfile").binmode?
        end

        it "gets the content type" do
          assert_equal "image/png", @subject.content_type
        end

        it "returns content type as a string" do
          expect(@subject.content_type).to be_a String
        end

        it "gets the file's size" do
          assert_equal 4456, @subject.size
        end

        it "returns false for a call to nil?" do
          assert ! @subject.nil?
        end

        it "generates a MD5 hash of the contents" do
          expected = Digest::MD5.file(@file.tempfile.path).to_s
          assert_equal expected, @subject.fingerprint
        end

        it "reads the contents of the file" do
          expected = @file.tempfile.read
          assert expected.length > 0
          assert_equal expected, @subject.read
        end
      end

      context "file with multiple possible content type" do
        before do
          MIME::Types.stubs(:type_for).returns([MIME::Type.new('image/x-png'), MIME::Type.new('image/png')])
          @subject = Paperclip.io_adapters.for(@file)
        end

        it "prefers officially registered mime type" do
          assert_equal "image/png", @subject.content_type
        end

        it "returns content type as a string" do
          expect(@subject.content_type).to be_a String
        end
      end

      context "file with content type derived from file command on *nix" do
        before do
          MIME::Types.stubs(:type_for).returns([])
          Paperclip.stubs(:run).returns("application/vnd.ms-office\n")
          @subject = Paperclip.io_adapters.for(@file)
        end

        it "returns content type without newline character" do
          assert_equal "application/vnd.ms-office", @subject.content_type
        end
      end
    end

    context "filename with restricted characters" do
      before do
        module Hashie
          class Mash < OpenStruct; end
        end
        @file = Hashie::Mash.new(
          filename: 'image:restricted.gif',
          type: 'image/png',
          tempfile: File.new(fixture_file("5k.png"))
        )
        @subject = Paperclip.io_adapters.for(@file)
      end

      it "does not generate filenames that include restricted characters" do
        assert_equal 'image_restricted.gif', @subject.original_filename
      end

      it "does not generate paths that include restricted characters" do
        expect(@subject.path).to_not match(/:/)
      end
    end

    context "empty file" do
      before do
        module Hashie
          class Mash < OpenStruct; end
        end
        @file = Hashie::Mash.new(
          filename: 'image:restricted.gif',
          type: 'image/png',
          tempfile: Tempfile.new("file_adapter_test")
        )
        @subject = Paperclip.io_adapters.for(@file)
      end

      it "provides correct mime-type" do
        assert_match %r{.*/x-empty}, @subject.content_type
      end
    end
  end
end

