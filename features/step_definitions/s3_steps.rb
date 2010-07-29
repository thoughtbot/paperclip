Given /I validate my S3 credentials/ do
  key = ENV['AWS_ACCESS_KEY_ID']
  secret = ENV['AWS_SECRET_ACCESS_KEY']

  key.should_not be_nil
  secret.should_not be_nil

  assert_credentials(key, secret)
end
