module Paperclip
  module TmpSaveable
    attr_reader :tmp_id

    # Deletes temporary uploads older than Paperclip.options[:tmp_expiry] (defaults to 1 hour).
    def self.clean_old_tmp_uploads!
      cutoff = Time.now.to_i - (Paperclip.options[:tmp_expiry] || 1.hour)
      Dir["#{tmp_serialize_root}/*.yml"].each do |f|
        if (obj = deserialize(f)) && obj.updated_at.present? && obj.updated_at < cutoff
          obj.delete_tmp
        end
      end
    end

    def self.tmp_serialize_root
      "#{Rails.root}/tmp/attachments"
    end

    def self.deserialize(path)
      YAML::load(File.read(path)).tap do |tmp|
        tmp.send(:initialize_storage)
      end
    end

    def tmp_id=(id)
      @tmp_id = id
      @tmp_id_set_explicitly = true
    end

    def generate_tmp_id
      self.tmp_id = SecureRandom.hex if tmp_id.nil? && !@tmp_id_set_explicitly
    end

    # Processes and saves the current file at the location determined by tmp_path.
    # Also serializes this object in a known location so it can be used to find the saved tmp files later.
    # If there is no current file or tmp_id, does nothing.
    def save_tmp
      return unless tmp_id.present? && original_filename.present?
      FileUtils.mkdir_p(File.dirname(tmp_serialize_path))
      File.open(tmp_serialize_path, 'w') { |f| f.write(YAML::dump(self)) }
      save(tmp: true)
    end

    # Retrieves a saved temporary Attachment object.
    def matching_saved_tmp
      if tmp_id.present? && File.exists?(tmp_serialize_path)
        Paperclip::TmpSaveable.deserialize(tmp_serialize_path)
      else
        nil
      end
    end

    # If a matching saved temp upload exists, assigns that as the file for this model.
    def copy_saved_tmp_if_appropriate
      if saved_tmp = matching_saved_tmp
        path = saved_tmp.tmp_path(:original)
        if !dirty? && @queued_for_delete.empty? && File.exists?(path)
          assign(File.open(path))
        end
      end
    end

    def clear_tmp
      matching_saved_tmp.try(:delete_tmp)
    end

    # Returns the url of the temporary upload as defined by the :tmp_url option.
    def tmp_url(style_name = default_style, options = {})
      @url_generator.for(style_name, default_options.merge(options).merge(:tmp => true))
    end

    # Returns the path of the temporary upload as defined by the :tmp_path option.
    def tmp_path(style_name = default_style)
      path = original_filename.nil? || tmp_id.nil? ? nil : interpolate(tmp_path_option, style_name)
      unescape(path)
    end

    private

    def tmp_path_option
      @options[:tmp_path].respond_to?(:call) ? @options[:tmp_path].call(self) : @options[:tmp_path]
    end

    # Gets the path where an Attachment with tmp_id matching our current tmp_id should be serialized
    # to for later retrieval and use.
    def tmp_serialize_path
      "#{Paperclip::TmpSaveable.tmp_serialize_root}/#{tmp_id}.yml"
    end
  end
end
