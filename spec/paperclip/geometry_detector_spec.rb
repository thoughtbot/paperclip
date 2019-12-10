require "spec_helper"

describe Paperclip::GeometryDetector do
  it "identifies an image and extract its dimensions" do
    allow_any_instance_of(Paperclip::GeometryParser).to receive(:make).and_return(:correct)
    file = fixture_file("5k.png")
    factory = Paperclip::GeometryDetector.new(file)

    output = factory.make

    expect(output).to eq :correct
  end

  it "identifies an image and extract its dimensions and orientation" do
    allow_any_instance_of(Paperclip::GeometryParser).to receive(:make).and_return(:correct)
    file = fixture_file("rotated.jpg")
    factory = Paperclip::GeometryDetector.new(file)

    output = factory.make

    expect(output).to eq :correct
  end

  it "avoids reading EXIF orientation if so configured" do
    begin
      Paperclip.options[:use_exif_orientation] = false
      allow_any_instance_of(Paperclip::GeometryParser).to receive(:make).and_return(:correct)
      file = fixture_file("rotated.jpg")
      factory = Paperclip::GeometryDetector.new(file)

      output = factory.make

      expect(output).to eq :correct
    ensure
      Paperclip.options[:use_exif_orientation] = true
    end
  end
end
