# encoding: utf-8
require './test/helper'
require 'paperclip/attachment'

class AttachmentProcessingTest < Test::Unit::TestCase
  def setup
    rebuild_model
  end

  context 'using validates_attachment_content_type' do
    should 'process attachments given a valid assignment' do
      file = File.new(fixture_file("5k.png"))
      Dummy.validates_attachment_content_type :avatar, :content_type => "image/png"
      instance = Dummy.new
      attachment = instance.avatar
      attachment.expects(:post_process_styles)

      attachment.assign(file)
    end

    should 'not process attachments given an invalid assignment with :not' do
      file = File.new(fixture_file("5k.png"))
      Dummy.validates_attachment_content_type :avatar, :not => "image/png"
      instance = Dummy.new
      attachment = instance.avatar
      attachment.expects(:post_process_styles).never

      attachment.assign(file)
    end

    should 'not process attachments given an invalid assignment with :content_type' do
      file = File.new(fixture_file("5k.png"))
      Dummy.validates_attachment_content_type :avatar, :content_type => "image/tiff"
      instance = Dummy.new
      attachment = instance.avatar
      attachment.expects(:post_process_styles).never

      attachment.assign(file)
    end

    should 'when validation :if clause returns false, allow what would be an invalid assignment' do
      invalid_assignment = File.new(fixture_file("5k.png"))
      Dummy.validates_attachment_content_type :avatar, :content_type => "image/tiff", :if => lambda{false}
      instance = Dummy.new
      attachment = instance.avatar
      attachment.expects(:post_process_styles)

      attachment.assign(invalid_assignment)
    end
  end

  context 'using validates_attachment' do
    should 'process attachments given a valid assignment' do
      file = File.new(fixture_file("5k.png"))
      Dummy.validates_attachment :avatar, :content_type => {:content_type => "image/png"}
      instance = Dummy.new
      attachment = instance.avatar
      attachment.expects(:post_process_styles)

      attachment.assign(file)
    end

    should 'not process attachments given an invalid assignment with :not' do
      file = File.new(fixture_file("5k.png"))
      Dummy.validates_attachment :avatar, :content_type => {:not => "image/png"}
      instance = Dummy.new
      attachment = instance.avatar
      attachment.expects(:post_process_styles).never

      attachment.assign(file)
    end

    should 'not process attachments given an invalid assignment with :content_type' do
      file = File.new(fixture_file("5k.png"))
      Dummy.validates_attachment :avatar, :content_type => {:content_type => "image/tiff"}
      instance = Dummy.new
      attachment = instance.avatar
      attachment.expects(:post_process_styles).never

      attachment.assign(file)
    end
  end
end
