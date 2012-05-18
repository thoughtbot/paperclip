require './test/helper'

class ProcessorTest < Test::Unit::TestCase
  should "instantiate and call #make when sent #make to the class" do
    processor = mock
    processor.expects(:make).with()
    Paperclip::Processor.expects(:new).with(:one, :two, :three).returns(processor)
    Paperclip::Processor.make(:one, :two, :three)
  end

  context "Calling #convert" do
    should "run the convert command with Cocaine" do
      Paperclip.options[:log_command] = false
      Cocaine::CommandLine.expects(:new).with("convert", "stuff", {}).returns(stub(:run))
      Paperclip::Processor.new('filename').convert("stuff")
    end
  end

  context "Calling #identify" do
    should "run the identify command with Cocaine" do
      Paperclip.options[:log_command] = false
      Cocaine::CommandLine.expects(:new).with("identify", "stuff", {}).returns(stub(:run))
      Paperclip::Processor.new('filename').identify("stuff")
    end
  end
end
