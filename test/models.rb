begin
  ActiveRecord::Base.connection.create_table :foos do |table|
    table.column :image_file_name, :string
    table.column :image_content_type, :string
  end
  ActiveRecord::Base.connection.create_table :bars do |table|
    table.column :document_file_name, :string
    table.column :document_content_type, :string
  end
rescue Exception
end

class Foo < ActiveRecord::Base
  has_attached_file :image, :attachment_type => :image,
                    :thumbnails => { :thumb  => "100x100>", :medium => "300x300>" },
                    :path_prefix => "."
end

class Bar < ActiveRecord::Base
  has_attached_file :document, :attachment_type => :document,
                    :path_prefix => "."
end