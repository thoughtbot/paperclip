require './test/helper'

class MediaTypeSpoofDetectionValidatorTest < Test::Unit::TestCase
  def setup
    rebuild_model
    @dummy = Dummy.new
  end

  should "be on the attachment without being explicitly added" do
    assert Dummy.validators_on(:avatar).any?{ |validator| validator.kind == :media_type_spoof_detection }
  end

  should "run when attachment is dirty" do
    # Make avatar dirty
    file = File.new(fixture_file("5k.png"), "rb")
    @dummy.avatar.assign(file)

    detector = mock("detector", :spoofed? => false)
    Paperclip::MediaTypeSpoofDetector.expects(:using).returns(detector)
    @dummy.valid?
  end

  should "not run when attachment is not dirty" do
    Paperclip::MediaTypeSpoofDetector.expects(:using).never
    @dummy.valid?
  end
end
