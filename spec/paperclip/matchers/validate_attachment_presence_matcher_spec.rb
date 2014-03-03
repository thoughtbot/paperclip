require 'spec_helper'
require 'paperclip/matchers'

describe Paperclip::Shoulda::Matchers::ValidateAttachmentPresenceMatcher do
  extend Paperclip::Shoulda::Matchers

  context "validate_attachment_presence" do
    before do
      reset_table("dummies") do |d|
        d.string :avatar_file_name
      end
      reset_class "Dummy"
      Dummy.has_attached_file :avatar
      Dummy.do_not_validate_attachment_file_type :avatar
      @matcher     = self.class.validate_attachment_presence(:avatar)
    end

    context "given a class with no validation" do
      should_reject_dummy_class
    end

    context "given a class with a matching validation" do
      before do
        Dummy.validates_attachment_presence :avatar
      end

      should_accept_dummy_class
    end

    context "given an instance with other attachment validations" do
      before do
        reset_table("dummies") do |d|
          d.string :avatar_file_name
          d.string :avatar_content_type
        end

        Dummy.class_eval do
          validates_attachment_presence :avatar
          validates_attachment_content_type :avatar, :content_type => 'image/gif'
        end

        @dummy = Dummy.new
        @matcher = self.class.validate_attachment_presence(:avatar)
      end

      it "it should validate properly" do
        @dummy.avatar = File.new fixture_file('5k.png')
        expect(@matcher).to accept(@dummy)
      end
    end

    context "using an :if to control the validation" do
      before do
        Dummy.class_eval do
          validates_attachment_presence :avatar, :if => :go
          attr_accessor :go
        end
        @dummy = Dummy.new
        @dummy.avatar = nil
      end

      it "run the validation if the control is true" do
        @dummy.go = true
        expect(@matcher).to accept(@dummy)
      end

      it "not run the validation if the control is false" do
        @dummy.go = false
        expect(@matcher).to_not accept(@dummy)
      end
    end
  end
end
