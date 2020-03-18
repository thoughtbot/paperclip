require 'spec_helper'

describe 'Attachment Processing' do
  before { rebuild_class }

  context 'using validates_attachment_content_type' do
    it "doesn't process attachments on assignment" do
      file = File.new(fixture_file("5k.png"))
      Dummy.validates_attachment_content_type :avatar, content_type: "image/png"
      instance = Dummy.new
      attachment = instance.avatar
      attachment.expects(:post_process_styles).never

      attachment.assign(file)
    end

    it 'processes attachments given the object is valid' do
      file = File.new(fixture_file("5k.png"))
      Dummy.validates_attachment_content_type :avatar, content_type: "image/png"
      instance = Dummy.new
      attachment = instance.avatar
      attachment.assign(file)
      attachment.expects(:post_process_styles)

      attachment.save
    end

    it 'does not process attachments given an invalid object with :not' do
      file = File.new(fixture_file("5k.png"))
      Dummy.validates_attachment_content_type :avatar, not: "image/png"
      instance = Dummy.new
      attachment = instance.avatar
      attachment.assign(file)
      attachment.expects(:post_process_styles).never

      attachment.save
    end

    it 'does not process attachments given an invalid object with :content_type' do
      file = File.new(fixture_file("5k.png"))
      Dummy.validates_attachment_content_type :avatar, content_type: "image/tiff"
      instance = Dummy.new
      attachment = instance.avatar
      attachment.assign(file)
      attachment.expects(:post_process_styles).never

      attachment.save
    end

    it 'allows what would be an invalid assignment when validation :if clause returns false' do
      invalid_assignment = File.new(fixture_file("5k.png"))
      Dummy.validates_attachment_content_type :avatar, content_type: "image/tiff", if: lambda{false}
      instance = Dummy.new
      attachment = instance.avatar
      attachment.assign(invalid_assignment)
      attachment.expects(:post_process_styles)

      attachment.save
    end
  end

  context 'using validates_attachment' do
    it "doesn't process attachments on assignment" do
      file = File.new(fixture_file("5k.png"))
      Dummy.validates_attachment :avatar, content_type: {content_type: "image/png"}
      instance = Dummy.new
      attachment = instance.avatar
      attachment.expects(:post_process_styles)

      attachment.assign(file)
    end

    it 'processes attachments given a valid object' do
      file = File.new(fixture_file("5k.png"))
      Dummy.validates_attachment :avatar, content_type: {content_type: "image/png"}
      instance = Dummy.new
      attachment = instance.avatar
      attachment.assign(file)
      attachment.expects(:post_process_styles)

      attachment.save
    end

    it 'does not process attachments given an invalid object with :not' do
      file = File.new(fixture_file("5k.png"))
      Dummy.validates_attachment :avatar, content_type: {not: "image/png"}
      instance = Dummy.new
      attachment = instance.avatar
      attachment.assign(file)
      attachment.expects(:post_process_styles).never

      attachment.save
    end

    it 'does not process attachments given an invalid object with :content_type' do
      file = File.new(fixture_file("5k.png"))
      Dummy.validates_attachment :avatar, content_type: {content_type: "image/tiff"}
      instance = Dummy.new
      attachment = instance.avatar
      attachment.assign(file)
      attachment.expects(:post_process_styles).never

      attachment.save
    end
  end
end
