module Paperclip
  module Schema
    def has_attached_file(name)
      column :"#{name}_file_name",    :string
      column :"#{name}_content_type", :string
      column :"#{name}_file_size",    :integer
      column :"#{name}_updated_at",   :datetime
    end
  end
end
