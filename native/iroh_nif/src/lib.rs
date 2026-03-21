pub mod connection;
pub mod endpoint;
pub mod stream;
pub mod ticket;

use once_cell::sync::Lazy;
use rustler::{nif, resource_impl, Resource, ResourceArc};
use tokio::runtime::Runtime;
use tokio_util::sync::CancellationToken;

mod atoms {
    rustler::atoms! {
        ok,
        error,
        nil,
        subject,

        bi_stream,
        closed,
        incoming_connection,
        uni_stream,
    }
}

static RUNTIME: Lazy<Runtime> = Lazy::new(|| Runtime::new().expect("Failed to create runtime"));

#[derive(Default, Clone)]
pub struct CancelToken(pub CancellationToken);

impl CancelToken {
    pub fn wrap(token: CancellationToken) -> ResourceArc<Self> {
        ResourceArc::new(CancelToken(token))
    }
}

#[resource_impl]
impl Resource for CancelToken {}

#[nif]
fn canceltoken_cancel(token: ResourceArc<CancelToken>) {
    token.0.cancel();
}

rustler::init!("iroh_nif");
