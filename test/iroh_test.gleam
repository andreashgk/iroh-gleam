import gleam/bit_array
import gleam/erlang/process
import gleam/string
import gleeunit
import gleeunit/should
import iroh/connection
import iroh/endpoint
import iroh/endpoint/relay_mode
import iroh/incoming
import iroh/stream
import iroh/ticket

pub fn main() {
  gleeunit.main()
}

/// Helper to prevent tests from running indefinitely.
fn with_timeout(timeout: Int, task: fn() -> a) -> a {
  let self = process.new_subject()

  process.spawn(fn() {
    let result = task()
    process.send(self, result)
  })

  case process.receive(self, timeout * 1000) {
    Ok(result) -> result
    Error(Nil) -> panic as "Test timed out."
  }
}

fn endpoint() -> endpoint.Endpoint {
  let assert Ok(endpoint) =
    endpoint.builder()
    |> endpoint.with_relay_mode(relay_mode.Disabled)
    |> endpoint.with_alpns([<<"test">>])
    |> endpoint.bind()

  endpoint
}

pub fn endpoint_build_test() {
  use <- with_timeout(5)

  let _ = endpoint()
}

pub fn endpoint_close_test() {
  use <- with_timeout(5)

  let e = endpoint()
  endpoint.close(e)
  endpoint.is_closed(e) |> should.be_true()
}

pub fn endpoint_close_event_test() {
  use <- with_timeout(5)

  let e = endpoint()

  let subject = process.new_subject()
  endpoint.subscribe(e, subject)

  endpoint.close(e)

  let assert Ok(endpoint.Closed) = process.receive(subject, 5000)
    as "Did not receive close event"
}

pub fn endpoint_connect_test() {
  use <- with_timeout(5)

  let e1 = endpoint()
  let e2 = endpoint()

  let subject = process.new_subject()
  endpoint.subscribe(e1, subject)

  process.spawn(fn() {
    let assert Ok(_con) = endpoint.connect(e2, endpoint.addr(e1), <<"test">>)
      as "Failed to open connection"
  })

  let assert Ok(endpoint.IncomingConnection(incoming)) =
    process.receive(subject, 5000)
    as "Did not receive connection"

  let assert Ok(_con) = incoming.accept(incoming)
    as "Failed to accept connection"
}

pub fn endpoint_id_test() {
  use <- with_timeout(5)

  let e = endpoint()
  endpoint.id(e)
  |> endpoint.public_key_to_string
  |> string.length
  |> should.equal(64)
}

pub fn endpoint_addr_test() {
  use <- with_timeout(5)

  endpoint.addr(endpoint())
}

pub fn connection_refuse_test() {
  use <- with_timeout(5)

  let e1 = endpoint()
  let e2 = endpoint()

  process.spawn(fn() {
    let subject = process.new_subject()
    endpoint.subscribe(e1, subject)

    let assert Ok(endpoint.IncomingConnection(incoming)) =
      process.receive(subject, 5000)
      as "Did not receive connection"

    incoming.refuse(incoming)
  })

  let assert Error(
    "aborted by peer: the server refused to accept a new connection",
  ) = endpoint.connect(e2, endpoint.addr(e1), <<"test">>)
    as "Connection did not fail"
}

pub fn uni_stream_test() {
  use <- with_timeout(5)

  let e1 = endpoint()
  let e2 = endpoint()

  let message = <<"test">>

  let subject = process.new_subject()
  endpoint.subscribe(e1, subject)

  process.spawn(fn() {
    let assert Ok(con) = endpoint.connect(e2, endpoint.addr(e1), <<"test">>)
      as "Failed to open connection"

    let assert Ok(stream) = connection.open_uni(con)
      as "Failed to open send stream"

    let assert Ok(Nil) = stream.write(stream, message)
      as "Failed to write to stream"
  })

  let assert Ok(endpoint.IncomingConnection(incoming)) =
    process.receive(subject, 5000)
    as "Did not receive connection"

  let assert Ok(con) = incoming.accept(incoming)
    as "Failed to accept connection"

  let subject = process.new_subject()
  connection.subscribe(con, subject)

  let assert Ok(connection.UniStream(stream)) = process.receive(subject, 5000)
    as "Failed to accept incoming stream"

  let assert Ok(<<"test">>) =
    stream.read_exact(stream, bit_array.byte_size(message))
}

pub fn bi_stream_test() {
  use <- with_timeout(5)

  let e1 = endpoint()
  let e2 = endpoint()

  let message = <<"This is a long messages that is to be returned exactly.">>

  let subject = process.new_subject()
  endpoint.subscribe(e1, subject)

  process.spawn(fn() {
    let assert Ok(con) = endpoint.connect(e2, endpoint.addr(e1), <<"test">>)
      as "Failed to open connection"

    let subject = process.new_subject()
    connection.subscribe(con, subject)

    let assert Ok(connection.BiStream(send, recv)) =
      process.receive(subject, 5000)
      as "Failed to accept incoming stream"

    let assert Ok(<<length:32>>) = stream.read_exact(recv, 4)
      as "Failed to read frame length"
    let assert Ok(message) = stream.read_exact(recv, length)
      as "Failed to read message"

    let assert Ok(Nil) = stream.write(send, message)
      as "Failed to return sent message"
  })

  let assert Ok(endpoint.IncomingConnection(incoming)) =
    process.receive(subject, 5000)
    as "Did not receive connection"

  let assert Ok(con) = incoming.accept(incoming)
    as "Failed to accept connection"

  let assert Ok(#(send, recv)) = connection.open_bi(con)

  let bs = <<bit_array.byte_size(message):32>>
  let assert Ok(Nil) = stream.write(send, bs)
    as "Failed to write length to stream"
  let assert Ok(Nil) = stream.write(send, message)
    as "Failed to write to stream"

  let assert Ok(received_message) =
    stream.read_exact(recv, bit_array.byte_size(message))
    as "Failed to read final message"

  should.equal(message, received_message)
}

pub fn ticket_test() {
  use <- with_timeout(5)

  let endpoint = endpoint()
  let assert Ok(_res) =
    endpoint |> endpoint.addr |> ticket.from_addr |> ticket.to_addr
}
