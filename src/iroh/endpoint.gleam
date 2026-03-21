import gleam/erlang/process
import gleam/option
import iroh
import iroh/connection
import iroh/endpoint/relay_mode
import iroh/incoming

/// An address to an iroh endpoint.
pub type Address

/// An iroh endpoint.
///
/// Needs to be closed manually on exit with `endpoint.close`.
pub type Endpoint

pub type SecretKey

pub type PublicKey

pub type Event {
  IncomingConnection(incoming.Incoming)
  Closed
}

/// Builder type to construct an endpoint.
pub type Builder {
  Builder(
    secret_key: option.Option(SecretKey),
    alpns: List(BitArray),
    relay_mode: relay_mode.RelayMode,
  )
}

pub fn builder() -> Builder {
  Builder(secret_key: option.None, alpns: [], relay_mode: relay_mode.Disabled)
}

pub fn with_secret_key(builder: Builder, secret_key: SecretKey) -> Builder {
  Builder(..builder, secret_key: option.Some(secret_key))
}

pub fn with_alpns(builder: Builder, alpns: List(BitArray)) -> Builder {
  Builder(..builder, alpns: alpns)
}

pub fn with_relay_mode(
  builder: Builder,
  relay_mode: relay_mode.RelayMode,
) -> Builder {
  Builder(..builder, relay_mode: relay_mode)
}

/// Consumes the builder, creating and binding the endpoint with the configured settings.
pub fn bind(builder: Builder) -> Result(Endpoint, String) {
  let relay_str = case builder.relay_mode {
    relay_mode.Default -> "default"
    relay_mode.Disabled -> "disabled"
  }
  let sk = case builder.secret_key {
    option.Some(sk) -> sk
    option.None -> secret_key_generate()
  }
  do_bind(sk, builder.alpns, relay_str)
}

@external(erlang, "iroh_nif", "endpoint_bind")
fn do_bind(
  sk: SecretKey,
  alpns: List(BitArray),
  relay_mode: String,
) -> Result(Endpoint, String)

// TODO: may be broken right now
/// Waits until the endpoint comes online.
@external(erlang, "iroh_nif", "endpoint_online")
pub fn online(e: Endpoint) -> Nil

/// Close the endpoint. This will block the process to close existing connections.
@external(erlang, "iroh_nif", "endpoint_close")
pub fn close(e: Endpoint) -> Nil

/// Returns true if the endpoint has been closed.
@external(erlang, "iroh_nif", "endpoint_is_closed")
pub fn is_closed(e: Endpoint) -> Bool

/// Subscribe to events coming from the endpoint. This allows you to listen for incoming
/// connections. No connections are accepted if these events are not handled.
///
/// Canceling the returned token stops the event loop but does not close the endpoint.
@external(erlang, "iroh_nif", "endpoint_subscribe")
pub fn subscribe(
  e: Endpoint,
  subject: process.Subject(Event),
) -> iroh.CancellationToken

@external(erlang, "iroh_nif", "endpoint_id")
pub fn id(e: Endpoint) -> PublicKey

/// Get an endpoint's address.
@external(erlang, "iroh_nif", "endpoint_addr")
pub fn addr(e: Endpoint) -> Address

@external(erlang, "iroh_nif", "endpoint_connect")
pub fn connect(
  e: Endpoint,
  addr: Address,
  alpn: BitArray,
) -> Result(connection.Connection, String)

@external(erlang, "iroh_nif", "secret_key_generate")
pub fn secret_key_generate() -> SecretKey

@external(erlang, "iroh_nif", "secret_key_to_public")
pub fn secret_key_to_public(sk: SecretKey) -> PublicKey

@external(erlang, "iroh_nif", "public_key_to_string")
pub fn public_key_to_string(pk: PublicKey) -> String

@external(erlang, "iroh_nif", "public_key_from_string")
pub fn public_key_from_string(s: String) -> Result(PublicKey, String)

@external(erlang, "iroh_nif", "public_key_to_addr")
pub fn public_key_to_addr(pk: PublicKey) -> Address
