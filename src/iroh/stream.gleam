pub type SendStream

pub type RecvStream

@external(erlang, "iroh_nif", "stream_write")
pub fn write(stream: SendStream, data: BitArray) -> Result(Nil, String)

@external(erlang, "iroh_nif", "stream_finish")
pub fn finish(stream: SendStream) -> Result(Nil, String)

/// Reads up to `len` bytes from the stream.
@external(erlang, "iroh_nif", "stream_read")
pub fn read(stream: RecvStream, len: Int) -> Result(BitArray, String)

/// Reads exactly `len` bytes from the stream. Returns an error if the stream terminated before
/// being able to read this amount of bytes.
@external(erlang, "iroh_nif", "stream_read_exact")
pub fn read_exact(stream: RecvStream, len: Int) -> Result(BitArray, String)

/// Convenience method to read all remaining data into a BitArray.
///
/// Fails if more than `size_limit` bytes are read.
@external(erlang, "iroh_nif", "stream_read_to_end")
pub fn read_to_end(
  stream: RecvStream,
  size_limit: Int,
) -> Result(BitArray, String)
