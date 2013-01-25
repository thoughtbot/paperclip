require './test/helper'
require 'paperclip/has_attached_file'

class HasAttachedFileTest < Test::Unit::TestCase
  context '#define_on' do
    should 'define a setter on the class object' do
      a_class = stub('class', define_method: nil)
      has_attached_file = Paperclip::HasAttachedFile.new(:avatar, {})

      has_attached_file.define_on(a_class)

      assert_received(a_class, :define_method) do |expect|
        expect.with('avatar=')
      end
    end
  end
end
