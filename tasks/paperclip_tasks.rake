namespace :paperclip do
  # desc "Regenerates thumbnails for a given CLASS (and optional ATTACHMENT)"
  # task :refresh do
  #   klass = obtain_class
  #   attachment = ENV['ATTACHMENT']
  #   attachments = attachment.blank? ? klass.attachments : [attachment]
  #   instances = klass.find(:all)
  #   puts "Regenerating thumbnails for #{instances.length} instances:"
  #   instances.each do |instance|
  #     attachments.each do |attach|
  #       instance.send("process_#{attach}_thumbnails")
  #     end
  #     print instance.save ? "." : "x"; $stdout.flush
  #   end
  # end
  
  # desc "Cleans out unused attachments for the given CLASS (and optional ATTACHMENT)"
  # task :clean do
  # end
end