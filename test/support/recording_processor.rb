class RecordingProcessor
  def self.make(file, options, attachment)
    @style_hashes ||= []
    @style_hashes << options
    File.new('/etc/passwd')
  end

  def self.clear
    @style_hashes = []
  end

  def self.has_processed?(expected_style_hash)
    expected_geometries = expected_style_hash.values
    @style_hashes && @style_hashes.any? do |style_hash|
      expected_geometries.include?(style_hash[:geometry])
    end
  end
end

Paperclip.configure do |c|
  c.register_processor :recording, RecordingProcessor
end
