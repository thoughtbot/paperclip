require './test/helper'

class InterpolatedStringTest < Test::Unit::TestCase
  context "inheritance" do
    should "inherited from String" do
      assert Paperclip::InterpolatedString.new("paperclip").is_a? String
    end
  end

  context "#escape" do
    subject { Paperclip::InterpolatedString.new("paperclip foo").escape }

    should "returns an InterpolatedString object" do
      assert subject.is_a? Paperclip::InterpolatedString
    end

    should "escape the output string" do
      assert_equal "paperclip%20foo", subject
    end

    should "not double escape output string" do
      assert_equal "paperclip%20foo", subject.escape
    end
  end

  context "#unescape" do
    subject { Paperclip::InterpolatedString.new("paperclip%20foo").escape.unescape }

    should "returns an InterpolatedString object" do
      assert subject.is_a? Paperclip::InterpolatedString
    end

    should "unescape the output string" do
      assert_equal "paperclip%20foo", subject
    end

    should "not double unescape output string" do
      assert_equal "paperclip%20foo", subject.unescape
    end
  end

  context "#escaped?" do
    subject { Paperclip::InterpolatedString.new("paperclip") }

    should "returns true if string was escaped" do
      assert subject.escape.escaped?
    end

    should "returns false if string wasn't escaped" do
      assert !subject.escaped?
    end
  end

  context "#force_escape" do
    subject { Paperclip::InterpolatedString.new("paperclip") }
    setup { subject.force_escape }

    should "sets escaped flag to true" do
      assert subject.escaped?
    end
  end
end
