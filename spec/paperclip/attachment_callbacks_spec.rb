require 'spec_helper'

describe Paperclip::Attachment do
  context "callbacks" do
    context "with content_type validation" do
      def rebuild(required_content_type)
        rebuild_class styles: { something: "100x100#" }
        Dummy.class_eval do
          validates_attachment_content_type :avatar, content_type: [required_content_type]
          before_avatar_post_process :do_before_avatar
          after_avatar_post_process :do_after_avatar
          before_post_process :do_before_all
          after_post_process :do_after_all
          def do_before_avatar ; end
          def do_after_avatar; end
          def do_before_all; end
          def do_after_all; end
        end
        @dummy = Dummy.new
      end

      context "that passes" do
        let!(:required_content_type) { "image/png" }
        before { rebuild(required_content_type) }
        let(:fake_file) {  StringIO.new(".").tap { |s| s.stubs(:to_tempfile).returns(s) } }

        it "calls all callbacks when assigned" do
          @dummy.expects(:do_before_avatar).with()
          @dummy.expects(:do_after_avatar).with()
          @dummy.expects(:do_before_all).with()
          @dummy.expects(:do_after_all).with()
          Paperclip::Thumbnail.expects(:make).returns(fake_file)
          @dummy.avatar = File.new(fixture_file("5k.png"))
        end
      end

      context "that fails" do
        let!(:required_content_type) { "image/jpeg" }
        before { rebuild(required_content_type) }

        it "does not call after callbacks when assigned" do
          # before callbacks ARE still called at present
          @dummy.expects(:do_before_all).with()
          @dummy.expects(:do_before_avatar).with()

          # But after_* are not
          @dummy.expects(:do_after_avatar).never
          @dummy.expects(:do_after_all).never
          Paperclip::Thumbnail.expects(:make).never

          @dummy.avatar = File.new(fixture_file("5k.png"))
        end
      end
    end
  end
end
