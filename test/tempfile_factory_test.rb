require './test/helper'

class Paperclip::TempfileFactoryTest < Test::Unit::TestCase
    
  should "be able to generate a tempfile with the right name" do
    file = subject.generate("omg.png")
  end

  context "Name of temp file" do

    should "should not contain illegal character" do
      "&$+,/:;=?@<>[]{}|\^~%# ".split(//).each do |character|
        file = subject.generate("#{character}filename.png")
        !File.basename(file.path).include? character
      end
    end

  end
end
