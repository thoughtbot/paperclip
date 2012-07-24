require './test/helper'
require 'paperclip/style_remover'

class StyleRemoverTest < Test::Unit::TestCase
  should 'process the specific style' do
    register_recording_processor

    Dummy = rebuild_model styles: { large: '24x24' }, processors: [:recording]
    dummy = Dummy.new
    dummy.avatar = File.new(fixture_file("50x50.png"), 'rb')
    dummy.save

    large_path = dummy.avatar.path(:large)
    original_path = dummy.avatar.path(:original)

    Paperclip::StyleRemover.run(:dummy, :avatar, :large)

    assert !File.exist?(large_path)
    assert File.exist?(original_path)
  end
end
