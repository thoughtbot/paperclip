require 'active_support/concern'
require 'paperclip/validators/attachment_content_type_validator'
require 'paperclip/validators/attachment_presence_validator'
require 'paperclip/validators/attachment_size_validator'

module Paperclip
  module Validators
    extend ActiveSupport::Concern

    included do
      extend  HelperMethods
      include HelperMethods
    end
  end
end
