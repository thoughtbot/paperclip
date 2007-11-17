module Paperclip

  # Holds the options defined by a call to has_attached_file. If options are not defined here as methods
  # they will still be found through +method_missing+. Default values can be modified by modifying the
  # hash returned by AttachmentDefinition.defaults directly.
  class AttachmentDefinition

    def self.defaults
      @defaults ||= {
        :path               => ":rails_root/public/:class/:attachment/:id/:style_:filename",
        :url                => "/:class/:attachment/:id/:style_:filename",
        :missing_url        => "/:class/:attachment/:style_missing.png",
        :attachment_type    => :image,
        :thumbnails         => {},
        :delete_on_destroy  => true,
        :default_style      => :original
      }
    end

    def initialize name, options
      @name    = name
      @options = AttachmentDefinition.defaults.merge options
    end

    def name
      @name
    end

    # A hash of all styles of the attachment. Essentially all the thumbnails
    # plus the original.
    def styles
      @styles ||= thumbnails.merge(:original => nil)
    end

    # A hash of all defined thumbnails for this attachment.
    def thumbnails
      @thumbnails ||= @options[:thumbnails] || {}
    end

    # A convenience method to insert validation options into the options hash
    # after the attachment has been defined.
    def validate thing, *constraints
      @options[:"validate_#{thing}"] = (constraints.length == 1 ? constraints.first : constraints)
    end

    def validations
      @validations ||= @options.inject({}) do |valids, opts|
        key, val = opts
        if (m = key.to_s.match(/^validates?_(.+)/))
          valids[m[1].to_sym] = val
        end
        valids
      end
    end

    # Any option passed in that does not explicitly appear in this class can be accessed through methods
    # regardless, as they are caught by +method_missing+. This does mean that it's probably not a good idea,
    # if you plan on extending Paperclip, to have an option that has the same name as a method on +Object+.
    def method_missing meth, *args
      @options[meth]
    end
  end
end