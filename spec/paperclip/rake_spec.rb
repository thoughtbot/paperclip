require 'spec_helper'
require 'rake'
load './lib/tasks/paperclip.rake'

describe Rake do
  context "calling `rake paperclip:refresh:thumbnails`" do
    before do
      rebuild_model
      allow(Paperclip::Task).to receive(:obtain_class).and_return('Dummy')
      @bogus_instance = Dummy.new
      @bogus_instance.id = 'some_id'
      allow(@bogus_instance.avatar).to receive(:reprocess!)
      @valid_instance = Dummy.new
      allow(@valid_instance.avatar).to receive(:reprocess!)
      allow(Paperclip::Task).to receive(:log_error)
      allow(Paperclip).to receive(:each_instance_with_attachment).and_yield @bogus_instance, @valid_instance
    end
    context "when there is an exception in reprocess!" do
      before do
        allow(@bogus_instance.avatar).to receive(:reprocess!).and_raise
      end

      it "catches the exception" do
        assert_nothing_raised do
          ::Rake::Task['paperclip:refresh:thumbnails'].execute
        end
      end

      it "continues to the next instance" do
        expect(@valid_instance.avatar).to receive(:reprocess!)
        ::Rake::Task['paperclip:refresh:thumbnails'].execute
      end

      it "prints the exception" do
        exception_msg = 'Some Exception'
        allow(@bogus_instance.avatar).to receive(:reprocess!).and_raise(exception_msg)
        expect(Paperclip::Task).to receive(:log_error) do |str|
          str.match exception_msg
        end
        ::Rake::Task['paperclip:refresh:thumbnails'].execute
      end

      it "prints the class name" do
        expect(Paperclip::Task).to receive(:log_error) do |str|
          str.match 'Dummy'
        end
        ::Rake::Task['paperclip:refresh:thumbnails'].execute
      end

      it "prints the instance ID" do
        expect(Paperclip::Task).to receive(:log_error) do |str|
          str.match "ID #{@bogus_instance.id}"
        end
        ::Rake::Task['paperclip:refresh:thumbnails'].execute
      end
    end

    context "when there is an error in reprocess!" do
      before do
        @errors = spy('errors')
        allow(@errors).to receive(:full_messages).and_return([''])
        allow(@errors).to receive(:blank?).and_return(false)
        allow(@bogus_instance).to receive(:errors).and_return(@errors)
      end

      it "continues to the next instance" do
        expect(@valid_instance.avatar).to receive(:reprocess!)
        ::Rake::Task['paperclip:refresh:thumbnails'].execute
      end

      it "prints the error" do
        error_msg = 'Some Error'
        allow(@errors).to receive(:full_messages).and_return([error_msg])
        expect(Paperclip::Task).to receive(:log_error) do |str|
          str.match error_msg
        end
        ::Rake::Task['paperclip:refresh:thumbnails'].execute
      end

      it "prints the class name" do
        expect(Paperclip::Task).to receive(:log_error) do |str|
          str.match 'Dummy'
        end
        ::Rake::Task['paperclip:refresh:thumbnails'].execute
      end

      it "prints the instance ID" do
        expect(Paperclip::Task).to receive(:log_error) do |str|
          str.match "ID #{@bogus_instance.id}"
        end
        ::Rake::Task['paperclip:refresh:thumbnails'].execute
      end
    end
  end

  context "Paperclip::Task.log_error method" do
    it "prints its argument to STDERR" do
      msg = 'Some Message'
      expect($stderr).to receive(:puts).with(msg)
      Paperclip::Task.log_error(msg)
    end
  end
end
