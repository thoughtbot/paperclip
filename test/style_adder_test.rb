require './test/helper'
require 'paperclip/style_adder'

class StyleAdderTest < Test::Unit::TestCase
  should 'process the specific style' do
    register_recording_processor

    Dummy = rebuild_model styles: { thumbnail: '24x24' }, processors: [:recording]
    file = File.new(fixture_file("50x50.png"), 'rb')
    dummy = Dummy.new
    dummy.avatar = file
    dummy.save
    file.close

    Dummy.class_eval do
      has_attached_file :avatar, styles: { thumbnail: '24x24', large: '124x124' }, processors: [:recording]
      Paperclip.reset_duplicate_clash_check!
    end

    dummy_enumerator = Dummy.all

    RecordingProcessor.clear

    Paperclip::StyleAdder.run dummy_enumerator, :avatar, large: '124x124'

    assert RecordingProcessor.has_processed?(large: '124x124')
    assert !RecordingProcessor.has_processed?(thumbnail: '24x24')
  end
end
