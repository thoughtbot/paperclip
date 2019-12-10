require "spec_helper"

describe Paperclip::GeometryParser do
  it "identifies an image and extract its dimensions with no orientation" do
    allow(Paperclip::Geometry).to receive(:new).with(
      height: "73",
      width: "434",
      modifier: nil,
      orientation: nil
    ).and_return(:correct)
    factory = Paperclip::GeometryParser.new("434x73")

    output = factory.make

    assert_equal :correct, output
  end

  it "identifies an image and extract its dimensions with an empty orientation" do
    allow(Paperclip::Geometry).to receive(:new).with(
      height: "73",
      width: "434",
      modifier: nil,
      orientation: ""
    ).and_return(:correct)
    factory = Paperclip::GeometryParser.new("434x73,")

    output = factory.make

    assert_equal :correct, output
  end

  it "identifies an image and extract its dimensions and orientation" do
    allow(Paperclip::Geometry).to receive(:new).with(
      height: "200",
      width: "300",
      modifier: nil,
      orientation: "6"
    ).and_return(:correct)
    factory = Paperclip::GeometryParser.new("300x200,6")

    output = factory.make

    assert_equal :correct, output
  end

  it "identifies an image and extract its dimensions and modifier" do
    allow(Paperclip::Geometry).to receive(:new).with(
      height: "64",
      width: "64",
      modifier: "#",
      orientation: nil
    ).and_return(:correct)
    factory = Paperclip::GeometryParser.new("64x64#")

    output = factory.make

    assert_equal :correct, output
  end

  it "identifies an image and extract its dimensions, orientation, and modifier" do
    allow(Paperclip::Geometry).to receive(:new).with(
      height: "50",
      width: "100",
      modifier: ">",
      orientation: "7"
    ).and_return(:correct)
    factory = Paperclip::GeometryParser.new("100x50,7>")

    output = factory.make

    assert_equal :correct, output
  end
end
