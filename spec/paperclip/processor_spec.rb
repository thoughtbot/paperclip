require "spec_helper"

describe Paperclip::Processor do
  it "instantiates and call #make when sent #make to the class" do
    processor = double
    expect(processor).to receive(:make)
    expect(Paperclip::Processor).to receive(:new).with(:one, :two, :three).and_return(processor)
    Paperclip::Processor.make(:one, :two, :three)
  end

  context "Calling #convert" do
    it "runs the convert command with Terrapin" do
      Paperclip.options[:log_command] = false
      expect(Terrapin::CommandLine).to receive(:new).with("convert", "stuff", {}).and_return(double(run: nil))
      Paperclip::Processor.new("filename").convert("stuff")
    end
  end

  context "Calling #identify" do
    it "runs the identify command with Terrapin" do
      Paperclip.options[:log_command] = false
      expect(Terrapin::CommandLine).to receive(:new).with("identify", "stuff", {}).and_return(double(run: nil))
      Paperclip::Processor.new("filename").identify("stuff")
    end
  end
end
