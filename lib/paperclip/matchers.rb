require 'paperclip/matchers/have_attached_file_matcher'
require 'paperclip/matchers/validate_attachment_presence_matcher'
require 'paperclip/matchers/validate_attachment_content_type_matcher'
require 'paperclip/matchers/validate_attachment_size_matcher'

module Paperclip
  module Shoulda
    # Provides rspec-compatible matchers for testing Paperclip attachments.
    #
    # In spec_helper.rb, you'll need to require the matchers:
    #
    #   require "paperclip/matchers"
    #
    # And include the module:
    #
    #   Spec::Runner.configure do |config|
    #     config.include Paperclip::Shoulda::Matchers
    #   end
    #
    # Example:
    #   describe User do
    #     it { should have_attached_file(:avatar) }
    #     it { should validate_attachment_presence(:avatar) }
    #     it { should validate_attachment_content_type(:avatar).
    #                   allowing('image/png', 'image/gif').
    #                   rejecting('text/plain', 'text/xml') }
    #     it { should validate_attachment_size(:avatar).
    #                   less_than(2.megabytes) }
    #   end
    module Matchers
    end
  end
end
