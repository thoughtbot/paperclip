require './test/helper'

class Paperclip::TempfileFactoryTest < Test::Unit::TestCase
  should 'generate a Tempfile with a random basename' do
    begin
      SecureRandom.stubs(hex: 'abcabc1234')
      file = Paperclip::TempfileFactory.new.generate('foo.png')
      assert_match /abcabc1234/, file.path
      file.close
    ensure
    end
  end
end
