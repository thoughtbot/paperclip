require './test/helper'

class Paperclip::TempfileFactoryTest < Test::Unit::TestCase
  should "be able to generate a tempfile with the right name" do
    file = subject.generate("omg.png")
  end
  should "be able to generate a tempfile with the right name with a tilde at the beginning" do
    file = subject.generate("~omg.png")
  end
  should "be able to generate a tempfile with the right name with a tilde at the end" do
    file = subject.generate("omg.png~")
  end
end
