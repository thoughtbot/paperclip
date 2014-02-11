require './test/helper'

class MediaTypeSpoofDetectionValidatorTest < Test::Unit::TestCase
  def setup
    rebuild_model
    @dummy = Dummy.new
  end

  def build_validator(options = {})
    @validator = Paperclip::Validators::MediaTypeSpoofDetectionValidator.new(options.merge(
      :attributes => :avatar
    ))
  end

  should "be on the attachment without being explicitly added" do
    assert Dummy.validators_on(:avatar).any?{ |validator| validator.kind == :media_type_spoof_detection }
  end

  should "return default error message for spoofed media type" do
    build_validator

    # Make avatar dirty
    file = File.new(fixture_file("5k.png"), "rb")
    @dummy.avatar.assign(file)

    detector = mock("detector", :spoofed? => true)
    Paperclip::MediaTypeSpoofDetector.stubs(:using).returns(detector)
    @validator.validate(@dummy)

    assert_equal "media type is spoofed", @dummy.errors[:avatar].first
  end
end
