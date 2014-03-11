$LOAD_PATH.push File.expand_path("../lib", __FILE__)
require 'paperclip/version'

Gem::Specification.new do |s|
  s.name              = "paperclip"
  s.version           = Paperclip::VERSION
  s.platform          = Gem::Platform::RUBY
  s.author            = "Jon Yurek"
  s.email             = ["jyurek@thoughtbot.com"]
  s.homepage          = "https://github.com/thoughtbot/paperclip"
  s.summary           = "File attachments as attributes for ActiveRecord"
  s.description       = "Easy upload management for ActiveRecord"
  s.license           = "MIT"

  s.rubyforge_project = "paperclip"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.requirements << "ImageMagick"
  s.required_ruby_version = ">= 1.9.2"

  s.add_dependency('activemodel', '>= 3.0.0')
  s.add_dependency('activesupport', '>= 3.0.0')
  s.add_dependency('cocaine', '~> 0.5.3')
  s.add_dependency('mime-types')

  s.add_development_dependency('activerecord', '>= 3.0.0')
  s.add_development_dependency('shoulda')
  s.add_development_dependency('rspec')
  s.add_development_dependency('appraisal')
  s.add_development_dependency('mocha')
  s.add_development_dependency('aws-sdk', '>= 1.5.7')
  s.add_development_dependency('bourne')
  s.add_development_dependency('cucumber', '~> 1.3.11')
  s.add_development_dependency('aruba')
  s.add_development_dependency('nokogiri')
  # Ruby version < 1.9.3 can't install capybara > 2.0.3.
  s.add_development_dependency('capybara', '= 2.0.3')
  s.add_development_dependency('bundler')
  s.add_development_dependency('fog', '~> 1.0')
  s.add_development_dependency('launchy')
  s.add_development_dependency('rake')
  s.add_development_dependency('fakeweb')
  s.add_development_dependency('railties')
  s.add_development_dependency('actionmailer', '>= 3.0.0')
  s.add_development_dependency('generator_spec')
end
