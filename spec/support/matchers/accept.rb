# frozen_string_literal: true

RSpec::Matchers.define :accept do |expected|
  match do |actual|
    actual.matches?(expected)
  end
end
