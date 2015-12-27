# frozen_string_literal: true

RSpec::Matchers.define :exist do |expected|
  match do |actual|
    File.exist?(actual)
  end
end
