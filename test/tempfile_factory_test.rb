require './test/helper'

class Paperclip::TempfileFactoryTest < Test::Unit::TestCase
  should "be able to generate a tempfile with the right name" do
    file = subject.generate("omg.png")
    assert File.extname(file.path), "png"
  end

  should "be able to generate a tempfile with the right name with a tilde at the beginning" do
    file = subject.generate("~omg.png")
    assert File.extname(file.path), "png"
  end

  should "be able to generate a tempfile with the right name with a tilde at the end" do
    file = subject.generate("omg.png~")
    assert File.extname(file.path), "png"
  end

  should "be able to generate a tempfile from a file with a really long name" do
    filename = "#{"longfilename" * 100}.png"
    file = subject.generate(filename)
    assert File.extname(file.path), "png"
  end

  should 'be able to take nothing as a parameter and not error' do
   file = subject.generate
   assert File.exists?(file.path)
  end
end
