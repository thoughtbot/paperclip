# frozen_string_literal: true

When /^I attach the file "([^"]*)" to "([^"]*)" on S3$/ do |file_path, field|
  definition = Paperclip::AttachmentRegistry.definitions_for(User)[field.downcase.to_sym]
  path = if defined?(::AWS)
           "https://paperclip.s3.amazonaws.com#{definition[:path]}"
         else
           "https://paperclip.s3-us-west-2.amazonaws.com#{definition[:path]}"
         end.dup

  path.gsub!(':filename', File.basename(file_path))
  path.gsub!(/:([^\/\.]+)/) do |match|
    "([^\/\.]+)"
  end
  FakeWeb.register_uri(:put, Regexp.new(path), :body => defined?(::AWS) ? "OK" : "<xml></xml>")
  step "I attach the file \"#{file_path}\" to \"#{field}\""
end

Then /^the file at "([^"]*)" should be uploaded to S3$/ do |url|
  FakeWeb.registered_uri?(:put, url)
end
