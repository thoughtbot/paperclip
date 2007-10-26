begin
  ActiveRecord::Base.connection.create_table :foos, :force => true do |table|
    table.column :image_file_name, :string
    table.column :image_content_type, :string
    table.column :image_file_size, :integer
  end
  ActiveRecord::Base.connection.create_table :bars, :force => true do |table|
    table.column :document_file_name, :string
    table.column :document_content_type, :string
    table.column :document_file_size, :integer
  end
  ActiveRecord::Base.connection.create_table :non_standards, :force => true do |table|
    table.column :resume_file_name, :string
    table.column :resume_content_type, :string
    table.column :resume_file_size, :integer
    table.column :avatar_file_name, :string
    table.column :avatar_content_type, :string
    table.column :avatar_file_size, :integer
  end
  ActiveRecord::Base.connection.create_table :ess_threes, :force => true do |table|
    table.column :resume_file_name, :string
    table.column :resume_content_type, :string
    table.column :resume_file_size, :integer
    table.column :avatar_file_name, :string
    table.column :avatar_content_type, :string
    table.column :avatar_file_size, :integer
  end
  ActiveRecord::Base.connection.create_table :negatives, :force => true do |table|
    table.column :this_is_the_wrong_name_file_name, :string
  end
rescue Exception
end

class Foo < ActiveRecord::Base
  has_attached_file :image, :attachment_type => :image,
                    :thumbnails => { :thumb  => "100x100>", :medium => "300x300>" },
                    :path_prefix => "./repository"
end

class Bar < ActiveRecord::Base
  has_attached_file :document, :attachment_type => :document,
                    :path_prefix => "./repository"
  validates_attached_file :document
end

class NonStandard < ActiveRecord::Base
  has_attached_file :resume, :attachment_type => :document,
                    :path_prefix => "/tmp",
                    :path => ":attachment_:id_:name",
                    :missing_url => "/:class/:style/:attachment/404.txt"
  has_attached_file :avatar, :attachment_type => :image,
                    :thumbnails => { :cropped => "200x10#",
                                     :bigger  => "1000x1000",
                                     :smaller => "200x200>",
                                     :square  => "150x150#" },
                    :path_prefix => "./repository",
                    :path => ":class/:attachment/:id/:style_:name",
                    :default_style => :square,
                    :missing_url => "/:class/:style/:attachment/404.png"
end

# class EssThree < ActiveRecord::Base
#   has_attached_file :resume, :attachment_type => :document,
#                     :path_prefix => "paperclip/test",
#                     :path => ":attachment_:id_:name",
#                     :missing_url => "/:class/:style/:attachment/404.txt",
#                     :storage => :S3
#   has_attached_file :avatar, :attachment_type => :image,
#                     :thumbnails => { :cropped => "200x10#",
#                                      :bigger  => "1000x1000",
#                                      :smaller => "200x200>",
#                                      :square  => "150x150#" },
#                     :path_prefix => "paperclip/test/images",
#                     :path => ":class/:attachment/:id/:style_:name",
#                     :default_style => :square,
#                     :missing_url => "/:class/:style/:attachment/404.png",
#                     :storage => :S3
# end

class Negative < ActiveRecord::Base
end