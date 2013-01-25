require './test/helper'
require 'tasks/attachments'

class AttachmentsTest < Test::Unit::TestCase
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
  end

  context '.definitions_for' do
    should 'produce the attachment name and options' do
      expected_definitions = {
        avatar: { yo: 'greeting' },
        greeter: { ciao: 'greeting' }
      }
      foo = Class.new
      Paperclip::Tasks::Attachments.add(foo, :avatar, { yo: 'greeting' })
      Paperclip::Tasks::Attachments.add(foo, :greeter, { ciao: 'greeting' })

      definitions = Paperclip::Tasks::Attachments.definitions_for(foo)

      assert_equal expected_definitions, definitions
    end
  end
end
