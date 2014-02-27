require 'spec_helper'

describe Paperclip::GeometryDetector do
  it 'identify an image and extract its dimensions' do
    Paperclip::GeometryParser.stubs(:new).with("434x66,").returns(stub(:make => :correct))
    file = fixture_file("5k.png")
    factory = Paperclip::GeometryDetector.new(file)

    output = factory.make

    expect(output).to eq :correct
  end

  it 'identify an image and extract its dimensions and orientation' do
    Paperclip::GeometryParser.stubs(:new).with("300x200,6").returns(stub(:make => :correct))
    file = fixture_file("rotated.jpg")
    factory = Paperclip::GeometryDetector.new(file)

    output = factory.make

    expect(output).to eq :correct
  end
end

