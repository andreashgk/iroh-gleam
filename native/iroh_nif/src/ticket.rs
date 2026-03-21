use std::str::FromStr;

use iroh_tickets::endpoint::EndpointTicket;
use rustler::{nif, Encoder, Env, ResourceArc, Term};

use crate::{atoms, endpoint::EndpointAddrResource};

#[nif]
fn ticket_from_addr(endpoint: ResourceArc<EndpointAddrResource>) -> String {
    EndpointTicket::new(endpoint.0.clone()).to_string()
}

#[nif]
fn ticket_to_addr(env: Env, ticket: String) -> Term {
    match EndpointTicket::from_str(&ticket) {
        Ok(ticket) => (
            atoms::ok(),
            ResourceArc::new(EndpointAddrResource(ticket.endpoint_addr().clone())),
        )
            .encode(env),
        Err(error) => (atoms::error(), error.to_string()).encode(env),
    }
}
