require './test/helper'
require 'paperclip/style_adder'

class StyleAdderTest < Test::Unit::TestCase
  should 'process the specific style' do
    Dummy = rebuild_model styles: { thumbnail: '24x24' }, processors: [:recording]
    dummy = Dummy.new
    dummy.avatar = File.new(fixture_file("50x50.png"), 'rb')
    dummy.save

    Dummy.class_eval do
      has_attached_file :avatar, styles: { thumbnail: '24x24', large: '124x124' }, processors: [:recording]
      Paperclip.reset_duplicate_clash_check!
    end

    RecordingProcessor.clear

    StyleAdder.run :dummies, :avatar, large: '124x124'

    assert RecordingProcessor.has_processed?(large: '124x124')
    assert !RecordingProcessor.has_processed?(thumbnail: '24x24')
  end
end
