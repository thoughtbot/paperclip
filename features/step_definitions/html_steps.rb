Then %r{I should see an image with a path of "([^"]*)"} do |path|
  page.should have_css("img[src^='#{path}']")
end

Then %r{^the file at "([^"]*)" is the same as "([^"]*)"$} do |web_file, path|
  visit(web_file)
  page.body.should == IO.read(path)
end
