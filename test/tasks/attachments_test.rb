require './test/helper'
require 'tasks/attachments'

class AttachmentsTest < Test::Unit::TestCase
  context '.names_for' do
    should 'include attachment names for the given class' do
      Foo = Class.new
      Paperclip::Tasks::Attachments.add(Foo, :avatar, {})

      assert_equal [:avatar], Paperclip::Tasks::Attachments.names_for(Foo)
    end

    should 'not include attachment names for other classes' do
      Foo = Class.new
      Bar = Class.new
      Paperclip::Tasks::Attachments.add(Foo, :avatar, {})
      Paperclip::Tasks::Attachments.add(Bar, :lover, {})

      assert_equal [:lover], Paperclip::Tasks::Attachments.names_for(Bar)
    end
  end

  context '.definitions_for' do

  end
end
