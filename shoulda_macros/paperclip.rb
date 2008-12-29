module Paperclip
  # =Paperclip Shoulda Macros
  #
  # These macros are intended for use with shoulda, and will be included into
  # your tests automatically. All of the macros use the standard shoulda
  # assumption that the name of the test is based on the name of the model
  # you're testing (that is, UserTest is the test for the User model), and
  # will load that class for testing purposes.
  module Shoulda
    # This will test whether you have defined your attachment correctly by
    # checking for all the required fields exist after the definition of the
    # attachment.
    def should_have_attached_file name, options = {}
      klass = self.name.gsub(/Test$/, '').constantize
      context "Class #{klass.name} with attachment #{name}" do
        should "respond to all the right methods" do
          ["#{name}", "#{name}=", "#{name}?"].each do |meth|
            assert klass.instance_methods.include?(meth), "#{klass.name} does not respond to #{name}."
          end
        end
      end
    end

    # Tests for validations on the presence of the attachment.
    def should_validate_attachment_presence name
      klass   = self.name.gsub(/Test$/, '').constantize
      context "Class #{klass.name} validating presence on #{name}" do
        context "when the assignment is nil" do
          setup do
            @attachment = klass.new.send(name)
            @attachment.assign(nil)
          end
          should "have a :presence validation error" do
            assert @assignment.errors[:presence]
          end
        end
        context "when the assignment is valid" do
          setup do
            @attachment = klass.new.send(name)
            @attachment.assign(nil)
          end
          should "have a :presence validation error" do
            assert ! @assignment.errors[:presence]
          end
        end
      end
    end

    # Tests that you have content_type validations specified. There are two
    # options, :valid and :invalid. Both accept an array of strings. The
    # strings should be a list of content types which will pass and fail
    # validation, respectively.
    def should_validate_attachment_content_type name, options = {}
      klass   = self.name.gsub(/Test$/, '').constantize
      valid   = [options[:valid]].flatten
      invalid = [options[:invalid]].flatten
      context "Class #{klass.name} validating content_types on #{name}" do
        valid.each do |type|
          context "being assigned a file with a content_type of #{type}" do
            setup do
              @file = StringIO.new(".")
              class << @file; attr_accessor :content_type; end
              @file.content_type = type
              @attachment = klass.new.send(name)
              @attachment.assign(@file)
            end
            should "not have a :content_type validation error" do
              assert ! @assignment.errors[:content_type]
            end
          end
        end
        invalid.each do |type|
          context "being assigned a file with a content_type of #{type}" do
            setup do
              @file = StringIO.new(".")
              class << @file; attr_accessor :content_type; end
              @file.content_type = type
              @attachment = klass.new.send(name)
              @attachment.assign(@file)
            end
            should "have a :content_type validation error" do
              assert @assignment.errors[:content_type]
            end
          end
        end
      end
    end

    # Tests to ensure that you have file size validations turned on. You
    # can pass the same options to this that you can to 
    # validate_attachment_file_size - :less_than, :greater_than, and :in.
    # :less_than checks that a file is less than a certain size, :greater_than
    # checks that a file is more than a certain size, and :in takes a Range or
    # Array which specifies the lower and upper limits of the file size.
    def should_validate_attachment_size name, options = {}
      klass   = self.name.gsub(/Test$/, '').constantize
      min     = options[:greater_than] || (options[:in] && options[:in].first) || 0
      max     = options[:less_than]    || (options[:in] && options[:in].last)  || (1.0/0)
      range   = (min..max)
      context "Class #{klass.name} validating file size on #{name}" do
        context "with an attachment that is #{max+1} bytes" do
          setup do
            @file = StringIO.new("." * (max+1))
            @attachment = klass.new.send(name)
            @attachment.assign(@file)
          end

          should "have a :size validation error" do
            assert @attachment.errors[:size]
          end
        end
        context "with an attachment that us #{max-1} bytes" do
          setup do
            @file = StringIO.new("." * (max-1))
            @attachment = klass.new.send(name)
            @attachment.assign(@file)
          end

          should "not have a :size validation error" do
            assert ! @attachment.errors[:size]
          end
        end

        if min > 0
          context "with an attachment that is #{min-1} bytes" do
            setup do
              @file = StringIO.new("." * (min-1))
              @attachment = klass.new.send(name)
              @attachment.assign(@file)
            end

            should "have a :size validation error" do
              assert @attachment.errors[:size]
            end
          end
          context "with an attachment that us #{min+1} bytes" do
            setup do
              @file = StringIO.new("." * (min+1))
              @attachment = klass.new.send(name)
              @attachment.assign(@file)
            end

            should "not have a :size validation error" do
              assert ! @attachment.errors[:size]
            end
          end
        end
      end
    end
  end
end

Test::Unit::TestCase.extend(Paperclip::Shoulda)
