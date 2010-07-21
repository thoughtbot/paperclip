Then %r{I should see an image with a path of "([^"]*)"} do |path|
  page.should have_css("img[src^='#{path}']")
end
