require './test/helper'

class AttachmentDefinitionsTest < Test::Unit::TestCase
  should 'return all of the attachments on the class' do
    reset_class "Dummy"
    Dummy.has_attached_file :avatar, {:path => "abc"}
    Dummy.has_attached_file :other_attachment, {:url => "123"}
    expected = {:avatar => {:path => "abc"}, :other_attachment => {:url => "123"}}

    assert_equal expected, Dummy.attachment_definitions
  end
end
