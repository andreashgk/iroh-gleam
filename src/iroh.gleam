pub type CancellationToken

@external(erlang, "iroh_nif", "canceltoken_cancel")
pub fn cancel(token: CancellationToken) -> Nil
