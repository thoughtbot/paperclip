namespace :images do
  desc "Regenerate images"
  task :regenerate => :environment do
    require 'open-uri'
    OpportunityPhoto.all.each do |photo|
      begin
        old_name = photo.image_file_name
        new_image = open(photo.image.url(:original, escape: false))
        class << new_image
          def original_filename; @original_filename; end
          def original_filename=(name); @original_filename = name; end
        end
        new_image.original_filename = old_name
        photo.image = new_image
        photo.save
      rescue => e
        puts "ERROR: #{e.message} while processing #{photo.id}"
      end
    end
  end
end
