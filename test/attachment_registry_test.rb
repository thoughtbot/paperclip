require './test/helper'
require 'paperclip/attachment_registry'

class AttachmentRegistryTest < Test::Unit::TestCase
  def setup
    Paperclip::AttachmentRegistry.clear
  end

  context '.names_for' do
    should 'include attachment names for the given class' do
      foo = Class.new
      Paperclip::AttachmentRegistry.register(foo, :avatar, {})

      assert_equal [:avatar], Paperclip::AttachmentRegistry.names_for(foo)
    end

    should 'not include attachment names for other classes' do
      foo = Class.new
      bar = Class.new
      Paperclip::AttachmentRegistry.register(foo, :avatar, {})
      Paperclip::AttachmentRegistry.register(bar, :lover, {})

      assert_equal [:lover], Paperclip::AttachmentRegistry.names_for(bar)
    end

    should 'produce the empty array for a missing key' do
      assert_empty Paperclip::AttachmentRegistry.names_for(Class.new)
    end
  end

  context '.each_definition' do
    should 'call the block with the class, attachment name, and options' do
      foo = Class.new
      expected_accumulations = [
        [foo, :avatar, { yo: 'greeting' }],
        [foo, :greeter, { ciao: 'greeting' }]
      ]
      expected_accumulations.each do |args|
        Paperclip::AttachmentRegistry.register(*args)
      end
      accumulations = []

      Paperclip::AttachmentRegistry.each_definition do |*args|
        accumulations << args
      end

      assert_equal expected_accumulations, accumulations
    end
  end

  context '.definitions_for' do
    should 'produce the attachment name and options' do
      expected_definitions = {
        avatar: { yo: 'greeting' },
        greeter: { ciao: 'greeting' }
      }
      foo = Class.new
      Paperclip::AttachmentRegistry.register(foo, :avatar, { yo: 'greeting' })
      Paperclip::AttachmentRegistry.register(foo, :greeter, { ciao: 'greeting' })

      definitions = Paperclip::AttachmentRegistry.definitions_for(foo)

      assert_equal expected_definitions, definitions
    end

    should "produce defintions for subclasses" do
      expected_definitions = { avatar: { yo: 'greeting' } }
      Foo = Class.new
      Bar = Class.new(Foo)
      Paperclip::AttachmentRegistry.register(Foo, :avatar, expected_definitions[:avatar])

      definitions = Paperclip::AttachmentRegistry.definitions_for(Bar)

      assert_equal expected_definitions, definitions
    end
  end

  context '.clear' do
    should 'remove all of the existing attachment definitions' do
      foo = Class.new
      Paperclip::AttachmentRegistry.register(foo, :greeter, { ciao: 'greeting' })

      Paperclip::AttachmentRegistry.clear

      assert_empty Paperclip::AttachmentRegistry.names_for(foo)
    end
  end
end
