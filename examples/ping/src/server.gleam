import gleam/erlang/process
import gleam/io
import gleam/result
import iroh
import iroh/connection
import iroh/endpoint
import iroh/incoming
import iroh/stream
import iroh/ticket

pub fn main() {
  let alpn = <<"iroh/ping/0">>

  let assert Ok(endpoint) =
    endpoint.builder()
    |> endpoint.with_alpns([alpn])
    |> endpoint.bind()

  let eid = endpoint.id(endpoint) |> endpoint.public_key_to_string
  io.println("Endpoint address: " <> eid)

  let ticket = endpoint.addr(endpoint) |> ticket.from_addr
  io.println("Ticket: " <> ticket)

  process.spawn(fn() {
    let subject = process.new_subject()
    endpoint.subscribe(endpoint, subject)

    listen(subject)
  })

  io.println("Listening for pings")
  process.sleep_forever()
}

fn listen(subject: process.Subject(endpoint.Event)) {
  case process.receive_forever(subject) {
    endpoint.Closed -> Nil

    endpoint.IncomingConnection(incoming) -> {
      let _ =
        incoming.accept(incoming)
        |> result.map_error(fn(err) {
          io.print("Error accepting incoming connection: " <> err)
        })
        |> result.map(fn(connection) {
          process.spawn(fn() { handle_conn(connection) })
        })

      listen(subject)
    }
  }
}

fn handle_conn(conn: connection.Connection) {
  let subject = process.new_subject()
  let cancel_token = connection.subscribe(conn, subject)

  let event =
    process.receive(subject, 10_000)
    |> result.replace_error("Accepting stream timed out")

  // Stop sending events to this process.
  iroh.cancel(cancel_token)

  event
  // Check that the received event is a new bidirectional stream.
  |> result.try(fn(event) {
    case event {
      connection.BiStream(s, r) -> Ok(#(s, r))
      _ -> Error("Unexpected event type")
    }
  })
  // Read the 'PING' message.
  |> result.try(fn(streams) {
    let #(send, recv) = streams

    stream.read_to_end(recv, 4)
    |> result.map_error(fn(err) { "Read error: " <> err })
    // Make sure the received message actually matches the expected format.
    |> result.try(fn(data) {
      case data {
        <<"PING">> -> Ok(Nil)
        _ -> Error("Malformed ping")
      }
    })
    |> result.map(fn(_) { send })
  })
  // Reply with 'PONG'.
  |> result.try(fn(send) {
    stream.write(send, <<"PONG">>)
    |> result.map_error(fn(err) { "Write error: " <> err })
  })
  |> result.map_error(io.println)
  |> result.map(fn(_) { io.println("Success") })
}
