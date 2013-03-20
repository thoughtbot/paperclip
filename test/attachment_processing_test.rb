# encoding: utf-8
require './test/helper'
require 'paperclip/attachment'

class AttachmentProcessingTest < Test::Unit::TestCase
  def setup
    rebuild_model
  end

  should 'process attachments given a valid assignment' do
    file = File.new(fixture_file("5k.png"))
    Dummy.validates_attachment_content_type :avatar, :content_type => "image/png"
    instance = Dummy.new
    attachment = instance.avatar
    attachment.expects(:post_process)

    attachment.assign(file)
  end

  should 'not process attachments if the assignment does not pass validation' do
    file = File.new(fixture_file("5k.png"))
    Dummy.validates_attachment_content_type :avatar, :content_type => "image/tiff"
    instance = Dummy.new
    attachment = instance.avatar
    attachment.expects(:post_process).never

    attachment.assign(file)
  end

  should 'process attachments given a valid assignment and a valid parent' do
    file = File.new(fixture_file("5k.png"))
    build_parent
    Dummy.belongs_to :parent, :inverse_of => :dummies
    Dummy.validates_attachment_content_type :avatar, :content_type => "image/png"
    Dummy.validates_attachment_presence :avatar, :if => :parent_checked?
    Dummy.class_eval do
      define_method(:parent_checked?) do
        parent.checked?
      end
    end

    instance = Parent.new(:checked => true, :dummies_attributes => { 0 => { :avatar => file }})
    attachment = instance.dummies.first.avatar
    attachment.expects(:post_process)

    attachment.assign(file)
  end
end
