require './test/helper'
require 'paperclip/schema'

class MockSchema
  include Paperclip::Schema

  def initialize(table_name = nil)
    @table_name = table_name
    @columns = {}
    @deleted_columns = []
  end

  def column(name, type)
    @columns[name] = type
  end

  def remove_column(table_name, column_name)
    return if @table_name && @table_name != table_name
    @columns.delete(column_name)
    @deleted_columns.push(column_name)
  end

  def has_column?(column_name)
    @columns.key?(column_name)
  end

  def deleted_column?(column_name)
    @deleted_columns.include?(column_name)
  end

  def type_of(column_name)
    @columns[column_name]
  end
end

class SchemaTest < Test::Unit::TestCase
  context "Migrating up" do
    setup do
      @schema = MockSchema.new
      @schema.has_attached_file :avatar
    end

    should "create the file_name column" do
      assert @schema.has_column?(:avatar_file_name)
    end

    should "create the content_type column" do
      assert @schema.has_column?(:avatar_content_type)
    end

    should "create the file_size column" do
      assert @schema.has_column?(:avatar_file_size)
    end

    should "create the updated_at column" do
      assert @schema.has_column?(:avatar_updated_at)
    end

    should "make the file_name column a string" do
      assert_equal :string, @schema.type_of(:avatar_file_name)
    end

    should "make the content_type column a string" do
      assert_equal :string, @schema.type_of(:avatar_content_type)
    end

    should "make the file_size column an integer" do
      assert_equal :integer, @schema.type_of(:avatar_file_size)
    end

    should "make the updated_at column a datetime" do
      assert_equal :datetime, @schema.type_of(:avatar_updated_at)
    end
  end

  context "Migrating down" do
    setup do
      @schema = MockSchema.new(:users)
      @schema.drop_attached_file :users, :avatar
    end

    should "remove the file_name column" do
      assert @schema.deleted_column?(:avatar_file_name)
    end

    should "remove the content_type column" do
      assert @schema.deleted_column?(:avatar_content_type)
    end

    should "remove the file_size column" do
      assert @schema.deleted_column?(:avatar_file_size)
    end

    should "remove the updated_at column" do
      assert @schema.deleted_column?(:avatar_updated_at)
    end
  end
end
