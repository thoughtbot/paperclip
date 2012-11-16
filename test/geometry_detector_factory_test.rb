require './test/helper'

class GeometryDetectorFactoryTest < Test::Unit::TestCase
  should 'identify an image and extract its dimensions' do
    Paperclip::GeometryParserFactory.stubs(:new).with("434x66,").returns(stub(:make => :correct))
    file = fixture_file("5k.png")
    factory = Paperclip::GeometryDetectorFactory.new(file)

    output = factory.make

    assert_equal :correct, output
  end

  should 'identify an image and extract its dimensions and orientation' do
    Paperclip::GeometryParserFactory.stubs(:new).with("300x200,6").returns(stub(:make => :correct))
    file = fixture_file("rotated.jpg")
    factory = Paperclip::GeometryDetectorFactory.new(file)

    output = factory.make

    assert_equal :correct, output
  end
end

