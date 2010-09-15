module Paperclip
  # Provides two helpers that can be used in migrations.
  #
  # In order to use this module, the target class should implement a
  # +column+ method that takes the column name and type, both as symbols,
  # as well as a +remove_column+ method that takes a table and column name,
  # also both symbols.
  module Schema
    @@columns = {:file_name    => :string,
                 :content_type => :string,
                 :file_size    => :integer,
                 :updated_at   => :datetime}

    def has_attached_file(attachment_name)
      with_columns_for(attachment_name) do |column_name, column_type|
        column(column_name, column_type)
      end
    end

    def drop_attached_file(table_name, attachment_name)
      with_columns_for(attachment_name) do |column_name, column_type|
        remove_column(table_name, column_name)
      end
    end

    protected

    def with_columns_for(attachment_name)
      @@columns.each do |suffix, column_type|
        column_name = full_column_name(attachment_name, suffix)
        yield column_name, column_type
      end
    end

    def full_column_name(attachment_name, column_name)
      "#{attachment_name}_#{column_name}".to_sym
    end
  end
end
