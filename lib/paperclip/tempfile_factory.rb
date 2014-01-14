module Paperclip
  class TempfileFactory

    def generate(name)
      @name = name
      file = Tempfile.new([basename, extension])
      file.binmode
      file
    end

    def extension
      File.extname(@name)
    end

    def basename
      Digest::MD5.hexdigest(File.basename(@name, extension))
    end
  end
end
