Then %r{I should see an image with a path of "([^"]*)"} do |path|
  page.should have_css("img[src^='#{path}']")
end

Then %r{^the file at "([^"]*)" is the same as "([^"]*)"$} do |web_file, path|
  expected = IO.read(path)
  actual = if web_file.match %r{^https?://}
    Net::HTTP.get(URI.parse(web_file))
  else
    visit(web_file)
    page.body
  end
  actual.force_encoding("UTF-8") if actual.respond_to?(:force_encoding)
  actual.should == expected
end
