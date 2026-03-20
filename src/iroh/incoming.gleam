import iroh/connection

/// A handle of an incoming connection that needs to be accepted or rejected.
///
/// Will be ignored when dropped without explicitly handling it.
pub type Incoming

/// Accept the incoming connection, turning it into a full connection.
///
/// Will panic if the incoming connection was already handled.
@external(erlang, "iroh_nif", "incoming_accept")
pub fn accept(incoming: Incoming) -> Result(connection.Connection, String)

/// Reject the incoming connection.
///
/// Will panic if the incoming connection was already handled.
@external(erlang, "iroh_nif", "incoming_refuse")
pub fn refuse(incoming: Incoming) -> Nil

/// Ignore the incoming connection, not sending any packets in response.
///
/// Will panic if the incoming connection was already handled.
@external(erlang, "iroh_nif", "incoming_ignore")
pub fn ignore(incoming: Incoming) -> Nil
