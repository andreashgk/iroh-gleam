import iroh/endpoint

/// A ticket contains information about how to connect to a remote endpoint.
pub type Ticket =
  String

/// Parse a ticket into an address.
@external(erlang, "iroh_nif", "ticket_to_addr")
pub fn to_addr(ticket: Ticket) -> Result(endpoint.Address, String)

/// Turns an address into a ticket string.
@external(erlang, "iroh_nif", "ticket_from_addr")
pub fn from_addr(addr: endpoint.Address) -> Ticket
