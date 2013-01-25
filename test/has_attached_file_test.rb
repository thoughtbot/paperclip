require './test/helper'
require 'paperclip/has_attached_file'

class HasAttachedFileTest < Test::Unit::TestCase
  context '#define_on' do
    should 'define a setter on the class object' do
      assert_adding_attachment('avatar').defines_method('avatar=')
    end

    should 'define a getter on the class object' do
      assert_adding_attachment('avatar').defines_method('avatar')
    end

    should 'define a query on the class object' do
      assert_adding_attachment('avatar').defines_method('avatar?')
    end

    should 'flush errors as part of validations' do
      assert_adding_attachment('avatar').defines_validation
    end
  end

  private

  def assert_adding_attachment(attachment_name)
    AttachmentAdder.new(attachment_name)
  end

  class AttachmentAdder
    include Mocha::API
    include Test::Unit::Assertions

    def initialize(attachment_name)
      @attachment_name = attachment_name
    end

    def defines_method(method_name)
      a_class = stub_class

      Paperclip::HasAttachedFile.define_on(a_class, @attachment_name, {})

      assert_received(a_class, :define_method) do |expect|
        expect.with(method_name)
      end
    end

    def defines_validation
      a_class = stub_class

      Paperclip::HasAttachedFile.define_on(a_class, @attachment_name, {})

      assert_received(a_class, :validates_each) do |expect|
        expect.with(@attachment_name)
      end
    end

    private

    def stub_class
      stub('class', validates_each: nil, define_method: nil)
    end
  end
end
