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

  s.rubyforge_project = "paperclip"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  if File.exists?('UPGRADING')
    s.post_install_message = File.read("UPGRADING")
  end

  s.requirements << "ImageMagick"
  s.required_ruby_version = ">= 1.9.2"

  s.add_dependency('activerecord', '>= 3.0.0')
  s.add_dependency('activemodel', '>= 3.0.0')
  s.add_dependency('activesupport', '>= 3.0.0')
  s.add_dependency('cocaine', '>= 0.0.2')
  s.add_dependency('mime-types')

  s.add_development_dependency('shoulda')
  s.add_development_dependency('appraisal')
  s.add_development_dependency('mocha')
  s.add_development_dependency('aws-sdk')
  s.add_development_dependency('bourne')
  s.add_development_dependency('sqlite3', '~> 1.3.4')
  s.add_development_dependency('cucumber', '~> 1.1.0')
  s.add_development_dependency('aruba')
  s.add_development_dependency('nokogiri')
  s.add_development_dependency('capybara')
  s.add_development_dependency('bundler')
  s.add_development_dependency('cocaine', '~> 0.2')
  s.add_development_dependency('fog')
  s.add_development_dependency('pry')
  s.add_development_dependency('launchy')
  s.add_development_dependency('rake')
  s.add_development_dependency('fakeweb')
end
