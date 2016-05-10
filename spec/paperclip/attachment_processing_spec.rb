# encoding: utf-8
require 'spec_helper'

describe 'Attachment Processing' do
  before { rebuild_class }

  context 'using validates_attachment_content_type' do
    it 'processes attachments given a valid assignment' do
      file = File.new(fixture_file("5k.png"))
      Dummy.validates_attachment_content_type :avatar, content_type: "image/png"
      instance = Dummy.new
      attachment = instance.avatar
      attachment.expects(:post_process_styles)

      attachment.assign(file)
    end

    it 'does not process attachments given an invalid assignment with :not' do
      file = File.new(fixture_file("5k.png"))
      Dummy.validates_attachment_content_type :avatar, not: "image/png"
      instance = Dummy.new
      attachment = instance.avatar
      attachment.expects(:post_process_styles).never

      attachment.assign(file)
    end

    it 'does not process attachments given an invalid assignment with :content_type' do
      file = File.new(fixture_file("5k.png"))
      Dummy.validates_attachment_content_type :avatar, content_type: "image/tiff"
      instance = Dummy.new
      attachment = instance.avatar
      attachment.expects(:post_process_styles).never

      attachment.assign(file)
    end

    it 'allows what would be an invalid assignment when validation :if clause returns false' do
      invalid_assignment = File.new(fixture_file("5k.png"))
      Dummy.validates_attachment_content_type :avatar, content_type: "image/tiff", if: lambda{false}
      instance = Dummy.new
      attachment = instance.avatar
      attachment.expects(:post_process_styles)

      attachment.assign(invalid_assignment)
    end

    context "with custom post-processing" do
      before do
        Dummy.class_eval do
          validates_attachment_content_type :avatar, content_type: "image/png"
          before_avatar_post_process :do_before_avatar
          after_avatar_post_process :do_after_avatar
          before_post_process :do_before_all
          after_post_process :do_after_all
          def do_before_avatar; end
          def do_after_avatar; end
          def do_before_all; end
          def do_after_all; end
        end
      end
      ## FALSE POSITIVE: This passes even before our change in callbacks.rb,
      # even though we know it had a problem with this. This passes
      # even if we don't trigger a validation error, we haven't succesfully
      # set up our callbacks at all somehow.
      it 'does not run custom post-processing if validation fails' do
        file = File.new(fixture_file("5k.png"))

        instance = Dummy.new
        attachment = instance.avatar

        attachment.expects(:do_after_avatar).never
        attachment.expects(:do_after_all).never

        attachment.assign(file)
      end
    end
  end

  context 'using validates_attachment' do
    it 'processes attachments given a valid assignment' do
      file = File.new(fixture_file("5k.png"))
      Dummy.validates_attachment :avatar, content_type: {content_type: "image/png"}
      instance = Dummy.new
      attachment = instance.avatar
      attachment.expects(:post_process_styles)

      attachment.assign(file)
    end

    it 'does not process attachments given an invalid assignment with :not' do
      file = File.new(fixture_file("5k.png"))
      Dummy.validates_attachment :avatar, content_type: {not: "image/png"}
      instance = Dummy.new
      attachment = instance.avatar
      attachment.expects(:post_process_styles).never

      attachment.assign(file)
    end

    it 'does not process attachments given an invalid assignment with :content_type' do
      file = File.new(fixture_file("5k.png"))
      Dummy.validates_attachment :avatar, content_type: {content_type: "image/tiff"}
      instance = Dummy.new
      attachment = instance.avatar
      attachment.expects(:post_process_styles).never

      attachment.assign(file)
    end
  end
end
