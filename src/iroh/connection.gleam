import gleam/erlang/process
import iroh
import iroh/stream

/// An established iroh connection.
pub type Connection

pub type Event {
  UniStream(stream.RecvStream)
  BiStream(stream.SendStream, stream.RecvStream)
  Closed
}

/// Initiates a new outgoing unidirectional stream.
///
/// This is a cheap operation.
@external(erlang, "iroh_nif", "connection_open_uni")
pub fn open_uni(conn: Connection) -> Result(stream.SendStream, String)

/// Initiates a new outgoing bidirectional stream.
///
/// This is a cheap operation.
@external(erlang, "iroh_nif", "connection_open_bi")
pub fn open_bi(
  conn: Connection,
) -> Result(#(stream.SendStream, stream.RecvStream), String)

/// Listen for connection events and send them to the provided subject.
@external(erlang, "iroh_nif", "connection_subscribe")
pub fn subscribe(
  conn: Connection,
  subject: process.Subject(Event),
) -> iroh.CancellationToken
