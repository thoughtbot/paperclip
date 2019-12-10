RSpec::Matchers.define :exist do |_expected|
  match do |actual|
    File.exist?(actual)
  end
end
