require "spec_helper"

describe Paperclip::ProcessorHelpers do
  describe ".load_processor" do
    context "when the file exists in lib/paperclip" do
      it "loads it correctly" do
        pathname = Pathname.new("my_app")
        main_path = "main_path"
        alternate_path = "alternate_path"

        allow(Rails).to receive(:root).and_return(pathname)
        expect(File).to receive(:expand_path).with(pathname.join("lib/paperclip", "custom.rb")).and_return(main_path)
        expect(File).to receive(:expand_path).with(pathname.join("lib/paperclip_processors", "custom.rb")).and_return(alternate_path)
        expect(File).to receive(:exist?).with(main_path).and_return(true)
        expect(File).to receive(:exist?).with(alternate_path).and_return(false)

        expect(Paperclip).to receive(:require).with(main_path)

        Paperclip.load_processor(:custom)
      end
    end

    context "when the file exists in lib/paperclip_processors" do
      it "loads it correctly" do
        pathname = Pathname.new("my_app")
        main_path = "main_path"
        alternate_path = "alternate_path"

        allow(Rails).to receive(:root).and_return(pathname)
        expect(File).to receive(:expand_path).with(pathname.join("lib/paperclip", "custom.rb")).and_return(main_path)
        expect(File).to receive(:expand_path).with(pathname.join("lib/paperclip_processors", "custom.rb")).and_return(alternate_path)
        expect(File).to receive(:exist?).with(main_path).and_return(false)
        expect(File).to receive(:exist?).with(alternate_path).and_return(true)

        expect(Paperclip).to receive(:require).with(alternate_path)

        Paperclip.load_processor(:custom)
      end
    end

    context "when the file does not exist in lib/paperclip_processors" do
      it "raises an error" do
        pathname = Pathname.new("my_app")
        main_path = "main_path"
        alternate_path = "alternate_path"

        allow(Rails).to receive(:root).and_return(pathname)
        allow(File).to receive(:expand_path).with(pathname.join("lib/paperclip", "custom.rb")).and_return(main_path)
        allow(File).to receive(:expand_path).with(pathname.join("lib/paperclip_processors", "custom.rb")).and_return(alternate_path)
        allow(File).to receive(:exist?).with(main_path).and_return(false)
        allow(File).to receive(:exist?).with(alternate_path).and_return(false)

        assert_raises(LoadError) { Paperclip.processor(:custom) }
      end
    end
  end
end
