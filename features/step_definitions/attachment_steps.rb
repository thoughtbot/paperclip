module AttachmentHelpers
  def fixture_path(filename)
    File.expand_path("#{PROJECT_ROOT}/test/fixtures/#{filename}")
  end

  def attachment_path(filename)
    File.expand_path("public/system/attachments/#{filename}")
  end
end
World(AttachmentHelpers)

When /^I modify my attachment definition to:$/ do |definition|
  content = in_current_dir { File.read("app/models/user.rb") }
  name = content[/has_attached_file :\w+/][/:\w+/]
  content.gsub!(/has_attached_file.+end/m, <<-FILE)
      #{definition}
      do_not_validate_attachment_file_type #{name}
    end
  FILE

  write_file "app/models/user.rb", content
  in_current_dir { FileUtils.rm_rf ".rbx" }
end

When /^I upload the fixture "([^"]*)"$/ do |filename|
  run_simple %(bundle exec #{runner_command} "User.create!(:attachment => File.open('#{fixture_path(filename)}'))")
end

Then /^the attachment "([^"]*)" should have a dimension of (\d+x\d+)$/ do |filename, dimension|
  in_current_dir do
    geometry = `identify -format "%wx%h" "#{attachment_path(filename)}"`.strip
    geometry.should == dimension
  end
end

Then /^the attachment "([^"]*)" should exist$/ do |filename|
  in_current_dir do
    File.exists?(attachment_path(filename)).should be
  end
end

When /^I swap the attachment "([^"]*)" with the fixture "([^"]*)"$/ do |attachment_filename, fixture_filename|
  in_current_dir do
    require 'fileutils'
    FileUtils.rm_f attachment_path(attachment_filename)
    FileUtils.cp fixture_path(fixture_filename), attachment_path(attachment_filename)
  end
end

Then /^the attachment should have the same content type as the fixture "([^"]*)"$/ do |filename|
  in_current_dir do
    require 'mime/types'
    attachment_content_type = `bundle exec #{runner_command} "puts User.last.attachment_content_type"`.strip
    attachment_content_type.should == MIME::Types.type_for(filename).first.content_type
  end
end

Then /^the attachment should have the same file name as the fixture "([^"]*)"$/ do |filename|
  in_current_dir do
    attachment_file_name = `bundle exec #{runner_command} "puts User.last.attachment_file_name"`.strip
    attachment_file_name.should == File.name(fixture_path(filename)).to_s
  end
end

Then /^the attachment should have the same file size as the fixture "([^"]*)"$/ do |filename|
  in_current_dir do
    attachment_file_size = `bundle exec #{runner_command} "puts User.last.attachment_file_size"`.strip
    attachment_file_size.should == File.size(fixture_path(filename)).to_s
  end
end

Then /^the attachment file "([^"]*)" should (not )?exist$/ do |filename, not_exist|
  in_current_dir do
    check_file_presence([attachment_path(filename)], !not_exist)
  end
end

Then /^I should have attachment columns for "([^"]*)"$/ do |attachment_name|
  in_current_dir do
    columns = eval(`bundle exec #{runner_command} "puts User.columns.map{ |column| [column.name, column.type] }.inspect"`.strip)
    expect_columns = [
      ["#{attachment_name}_file_name", :string],
      ["#{attachment_name}_content_type", :string],
      ["#{attachment_name}_file_size", :integer],
      ["#{attachment_name}_updated_at", :datetime]
    ]

    expect_columns.all?{ |column| columns.include? column }.should be_true
  end
end

Then /^I should not have attachment columns for "([^"]*)"$/ do |attachment_name|
  in_current_dir do
    columns = eval(`bundle exec #{runner_command} "puts User.columns.map{ |column| [column.name, column.type] }.inspect"`.strip)
    expect_columns = [
      ["#{attachment_name}_file_name", :string],
      ["#{attachment_name}_content_type", :string],
      ["#{attachment_name}_file_size", :integer],
      ["#{attachment_name}_updated_at", :datetime]
    ]

    expect_columns.none?{ |column| columns.include? column }.should be_true
  end
end
