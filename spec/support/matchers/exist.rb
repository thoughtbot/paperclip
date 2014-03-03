RSpec::Matchers.define :exist do |expected|
  match do |actual|
    File.exists?(actual)
  end
end
