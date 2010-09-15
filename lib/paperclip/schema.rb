module Paperclip
  module Schema
    def has_attached_file(name)
      column :"#{name}_file_name",    :string
      column :"#{name}_content_type", :string
      column :"#{name}_file_size",    :integer
      column :"#{name}_updated_at",   :datetime
    end

    def drop_attached_file(table_name, name)
      remove_column table_name, :"#{name}_file_name"
      remove_column table_name, :"#{name}_content_type"
      remove_column table_name, :"#{name}_file_size"
      remove_column table_name, :"#{name}_updated_at"
    end
  end
end
