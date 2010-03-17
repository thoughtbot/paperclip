require 'test/helper'

class HaveAttachedFileMatcherTest < Test::Unit::TestCase
  context "have_attached_file" do
    setup do
      @dummy_class = reset_class "Dummy"
      reset_table "dummies"
      @matcher     = self.class.have_attached_file(:avatar)
    end

    context "given a class with no attachment" do
      should_reject_dummy_class
    end

    context "given a class with an attachment" do
      setup do
        modify_table("dummies"){|d| d.string :avatar_file_name }
        @dummy_class.has_attached_file :avatar
      end

      should_accept_dummy_class
    end
  end
end
