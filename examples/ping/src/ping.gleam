import argv
import gleam/io
import gleam/result
import iroh/connection
import iroh/endpoint
import iroh/stream
import iroh/ticket

fn read_ticket(f: fn(String) -> Nil) {
  let args = argv.load().arguments
  case args {
    [] -> {
      io.println("No arguments provided")
    }
    [ticket, ..] -> f(ticket)
  }
}

/// Simple script to send a ping via iroh and await a pong.
pub fn main() {
  let alpn = <<"iroh/ping/0">>

  use ticket <- read_ticket

  let target_addr =
    ticket.to_addr(ticket)
    |> result.lazy_unwrap(fn() { panic as "Failed to parse ticket" })

  io.println("Creating endpoint")

  let assert Ok(endpoint) =
    endpoint.builder()
    |> endpoint.with_alpns([alpn])
    |> endpoint.bind()

  io.println("Connecting")

  let assert Ok(connection) = endpoint.connect(endpoint, target_addr, alpn)

  let assert Ok(#(send, recv)) = connection.open_bi(connection)

  let assert Ok(Nil) = stream.write(send, <<"PING">>)
  let assert Ok(Nil) = stream.finish(send)
  io.println("Sent ping")

  let assert Ok(<<"PONG">>) = stream.read_to_end(recv, 4)
  io.println("Received pong")

  endpoint.close(endpoint)
}
