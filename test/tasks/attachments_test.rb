require './test/helper'
require 'paperclip/tasks/attachments'

class AttachmentsTest < Test::Unit::TestCase
  def setup
    Paperclip::Tasks::Attachments.clear
  end

  context '.names_for' do
    should 'include attachment names for the given class' do
      foo = Class.new
      Paperclip::Tasks::Attachments.add(foo, :avatar, {})

      assert_equal [:avatar], Paperclip::Tasks::Attachments.names_for(foo)
    end

    should 'not include attachment names for other classes' do
      foo = Class.new
      bar = Class.new
      Paperclip::Tasks::Attachments.add(foo, :avatar, {})
      Paperclip::Tasks::Attachments.add(bar, :lover, {})

      assert_equal [:lover], Paperclip::Tasks::Attachments.names_for(bar)
    end

    should 'produce the empty array for a missing key' do
      assert_empty Paperclip::Tasks::Attachments.names_for(Class.new)
    end
  end

  context '.each_definition' do
    should 'call the block with the class, attachment name, and options' do
      foo = Class.new
      expected_accumulations = [
        [foo,:avatar, { yo: 'greeting' }],
        [foo, :greeter, { ciao: 'greeting' }]
      ]
      expected_accumulations.each do |args|
        Paperclip::Tasks::Attachments.add(*args)
      end
      accumulations = []

      Paperclip::Tasks::Attachments.each_definition do |*args|
        accumulations << args
      end

      assert_equal expected_accumulations, accumulations
    end
  end

  context '.clear' do
    should 'remove all of the existing attachment definitions' do
      foo = Class.new
      Paperclip::Tasks::Attachments.add(foo, :greeter, { ciao: 'greeting' })

      Paperclip::Tasks::Attachments.clear

      assert_empty Paperclip::Tasks::Attachments.names_for(foo)
    end
  end
end
