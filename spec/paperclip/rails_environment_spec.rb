require 'spec_helper'

describe Paperclip::RailsEnvironment do

  it "returns nil when Rails isn't defined" do
    resetting_rails_to(nil) do
      expect(Paperclip::RailsEnvironment.get).to be_nil
    end
  end

  it "returns nil when Rails.env isn't defined" do
    resetting_rails_to({}) do
      expect(Paperclip::RailsEnvironment.get).to be_nil
    end
  end

  it "returns the value of Rails.env if it is set" do
    resetting_rails_to(OpenStruct.new(env: "foo")) do
      expect(Paperclip::RailsEnvironment.get).to eq "foo"
    end
  end

  it "returns false when the Rails version is lower than 5" do
    setting_rails_version_to("4.2.0") do
      expect(Paperclip::RailsEnvironment.version5?).to be false
    end
  end

  it "returns true when the Rails version is 5 or more" do
    setting_rails_version_to("5.1.0") do
      expect(Paperclip::RailsEnvironment.version5?).to be true
    end
  end

  def resetting_rails_to(new_value)
    begin
      previous_rails = Object.send(:remove_const, "Rails")
      Object.const_set("Rails", new_value) unless new_value.nil?
      yield
    ensure
      Object.send(:remove_const, "Rails") if Object.const_defined?("Rails")
      Object.const_set("Rails", previous_rails)
    end
  end

  def setting_rails_version_to(version)
    begin
      current_version = Rails.version
      Rails.stubs(:version).returns(version)
      yield
    ensure
      Rails.stubs(:version).returns(current_version)
    end
  end
end
