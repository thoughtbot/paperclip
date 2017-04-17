module Paperclip
	class PrivateController < ::ApplicationController
		before_action :validate_params!
		before_action :set_attachment
		before_action :set_path
		before_action :confirm_attachment_access!
		rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found!
		rescue_from ::Paperclip::Errors::FileDoesNotExistError, with: :handle_not_found!
		rescue_from ::Paperclip::Errors::ControllerValidationError, with: :hadle_bad_params!
		rescue_from ::Paperclip::Errors::AccessDeniedError, with: :handle_access_denied!

		# Download action
		def download
			send_file(@path)
		end

		protected
		# Return the private arratcment registry
		def paperclip_whitelist
			super if self.class.superclass.instance_methods.include?(:paperclip_whitelist) # Call classes in an array so they appear in the registry.
			::Paperclip::PrivateAttachmentRegistry.registry 
		end

		private
		# Confirm class name is valid and attachment name is valid before calling constantize in set_attachment method.
		def validate_params!
			attachments = paperclip_whitelist[params[:class_name]]
			raise ::Paperclip::Errors::ControllerValidationError if attachments.nil? || !attachments.keys.map(&:to_s).include?(params[:attachment])
			@options = attachments[params[:attachment].to_sym]
		end	

		# Sets object, attachment, and styles
		def set_attachment
			klass = params[:class_name].constantize
			object_id = params[:id]
			@object = klass.find(object_id)
			@attachment = @object.send(params[:attachment])
			@styles = @options[:styles] || {}
			@styles = @styles.call(@attachment) if @styles.respond_to?(:call)
		end

		# Sets path and confirms the file exists.
		def set_path
			@path = @styles.keys.map(&:to_s).include?(params[:style]) ? @attachment.path(params[:style]) : @attachment.path
			raise ::Paperclip::Errors::FileDoesNotExistError unless File.exist?(@path)
		end

		# Confirms the download is allowed.
		def confirm_attachment_access!
			raise ::Paperclip::Errors::AccessDeniedError unless @object.respond_to?(:can_download_attachment?) && @object.can_download_attachment?(self, params.dup)
		end

		# Handles what should happen when the route params do not pass validation.
		def hadle_bad_params!
			head 400
		end

		# Handles what should happen when the record or file is not found.
		def handle_not_found!
			head 404
		end

		# Handles what should happen when the object's can_download_attachment? method does not return true.
		def handle_access_denied!
			head 401
		end


	end
end