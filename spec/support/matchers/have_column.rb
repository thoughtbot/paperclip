RSpec::Matchers.define :have_column do |column_name|
  chain :with_default do |default|
    @default = default
  end

  match do |columns|
    column = columns.detect{|column| column.name == column_name }
    column && column.default.to_s == @default.to_s
  end

  failure_message_for_should do |columns|
    "expected to find '#{column_name}', default '#{@default}' in #{columns.map{|column| [column.name, column.default] }}"
  end
end
