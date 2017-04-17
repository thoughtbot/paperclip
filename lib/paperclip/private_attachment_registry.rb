module Paperclip
	module PrivateAttachmentRegistry
		def self.registry
			@registry ||= {}
		end

		def self.register(klass, name, options)
			class_name = klass.to_s
			self.registry[class_name] ||= {}
			self.registry[class_name][name] = options
		end
	end
end

