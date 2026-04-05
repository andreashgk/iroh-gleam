import gleam/bit_array
import gleeunit/should
import iroh/endpoint

pub fn roundtrip_test() {
  let sk1 = endpoint.secret_key_generate()

  let assert Ok(sk2) =
    sk1
    |> endpoint.secret_key_to_bit_array
    |> endpoint.secret_key_from_bit_array

  should.equal(
    endpoint.secret_key_to_bit_array(sk1),
    endpoint.secret_key_to_bit_array(sk2),
  )
}

pub fn secret_key_length_test() {
  let sk = endpoint.secret_key_generate()

  should.equal(32, endpoint.secret_key_to_bit_array(sk) |> bit_array.byte_size)
}
