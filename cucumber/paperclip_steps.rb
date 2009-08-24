When /^I attach an? "([^\"]*)" "([^\"]*)" file to an? "([^\"]*)" on S3$/ do |attachment, extension, model|
  stub_paperclip_s3(model, attachment, extension)
  attach_file attachment,
              "features/support/paperclip/#{model.gsub(" ", "_").underscore}/#{attachment}.#{extension}"
end

