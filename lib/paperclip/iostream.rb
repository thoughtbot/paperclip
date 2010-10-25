# Provides method that can be included on File-type objects (IO, StringIO, Tempfile, etc) to allow stream copying
# and Tempfile conversion.
module IOStream
  # Returns a Tempfile containing the contents of the readable object.
  def to_tempfile(object)
    return object.to_tempfile if object.respond_to?(:to_tempfile)
    name = object.respond_to?(:original_filename) ? object.original_filename : (object.respond_to?(:path) ? object.path : "stream")
    tempfile = Paperclip::Tempfile.new(["stream", File.extname(name)])
    tempfile.binmode
    stream_to(object, tempfile)
  end

  # Copies one read-able object from one place to another in blocks, obviating the need to load
  # the whole thing into memory. Defaults to 8k blocks. Returns a File if a String is passed
  # in as the destination and returns the IO or Tempfile as passed in if one is sent as the destination.
  def stream_to object, path_or_file, in_blocks_of = 8192
    dstio = case path_or_file
            when String   then File.new(path_or_file, "wb+")
            when IO       then path_or_file
            when Tempfile then path_or_file
            end
    buffer = ""
    object.rewind
    while object.read(in_blocks_of, buffer) do
      dstio.write(buffer)
    end
    dstio.rewind
    dstio
  end
end

# Corrects a bug in Windows when asking for Tempfile size.
if defined? Tempfile
  class Tempfile
    def size
      if @tmpfile
        @tmpfile.fsync
        @tmpfile.flush
        @tmpfile.stat.size
      else
        0
      end
    end
  end
end
