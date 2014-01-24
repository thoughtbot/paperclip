require './test/helper'

class MediaTypeSpoofDetectionValidatorTest < Test::Unit::TestCase
  def setup
    rebuild_model
    @dummy = Dummy.new
  end

  should "be on the attachment without being explicitly added" do
    assert Dummy.validators_on(:avatar).any?{ |validator| validator.kind == :media_type_spoof_detection }
  end
end
