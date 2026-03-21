use std::str::FromStr;

use iroh::{Endpoint, EndpointAddr, PublicKey, RelayMode, SecretKey};
use rustler::{
    nif, resource_impl, Atom, Binary, Encoder, Env, LocalPid, OwnedEnv, Resource, ResourceArc, Term,
};
use tokio::select;
use tokio_util::sync::CancellationToken;

use crate::{
    atoms,
    connection::{ConnectionResource, IncomingResource},
    CancelToken, RUNTIME,
};

pub struct SecretKeyResource(pub SecretKey);

#[resource_impl]
impl Resource for SecretKeyResource {}

pub struct PublicKeyResource(pub PublicKey);

#[resource_impl]
impl Resource for PublicKeyResource {}

pub struct EndpointAddrResource(pub EndpointAddr);

#[resource_impl]
impl Resource for EndpointAddrResource {}

pub struct EndpointResource {
    pub endpoint: Endpoint,
}

#[resource_impl]
impl Resource for EndpointResource {
    fn destructor(self, _env: Env<'_>) {
        RUNTIME.spawn(async move {
            self.endpoint.close().await;
        });
    }
}

#[nif(schedule = "DirtyIo")]
fn endpoint_bind<'a>(
    env: Env<'a>,
    sk: ResourceArc<SecretKeyResource>,
    alpns: Vec<Binary<'a>>,
    relay_mode: String,
) -> Term<'a> {
    let res: Result<Endpoint, String> = RUNTIME.block_on(async {
        let mut builder = Endpoint::builder(iroh::endpoint::presets::N0);
        if relay_mode == "disabled" {
            builder = builder.relay_mode(RelayMode::Disabled);
        }
        builder
            .secret_key(sk.0.clone())
            .alpns(alpns.into_iter().map(|s| s.to_vec()).collect())
            .bind()
            .await
            .map_err(|e| e.to_string())
    });

    match res {
        Ok(ep) => (
            atoms::ok(),
            ResourceArc::new(EndpointResource { endpoint: ep }),
        )
            .encode(env),
        Err(e) => (atoms::error(), e).encode(env),
    }
}

#[nif(schedule = "DirtyIo")]
fn endpoint_online(er: ResourceArc<EndpointResource>) {
    RUNTIME.block_on(async {
        er.endpoint.online().await;
    });
}

#[nif(schedule = "DirtyIo")]
fn endpoint_close(er: ResourceArc<EndpointResource>) {
    RUNTIME.block_on(async {
        er.endpoint.close().await;
    });
}

#[nif]
fn endpoint_is_closed(er: ResourceArc<EndpointResource>) -> bool {
    er.endpoint.is_closed()
}

#[nif]
fn endpoint_subscribe(
    er: ResourceArc<EndpointResource>,
    subject: Term,
) -> ResourceArc<CancelToken> {
    let env = OwnedEnv::new();

    let (s, pid, reference): (Atom, LocalPid, Term) = subject.decode().unwrap();
    assert_eq!(s, atoms::subject());

    let reference = env.save(reference);
    let endpoint = er.endpoint.clone();

    let token = CancellationToken::new();
    let ret_token = CancelToken::wrap(token.clone());

    RUNTIME.spawn(async move {
        let env = env;
        loop {
            let incoming = select! {
                biased;
                _ = token.cancelled() => return,
                incoming = endpoint.accept() => match incoming {
                    Some(v) => v,
                    None => {
                        _ = env.run(|env| {
                            let reference = reference.load(env);
                            env.send(&pid, (reference, atoms::closed()))
                        });
                        return;
                    },
                },
            };

            let res = ResourceArc::new(IncomingResource {
                incoming: parking_lot::Mutex::new(Some(incoming)),
            });

            let result = env.run(|env| {
                let reference = reference.load(env);
                env.send(&pid, (reference, (atoms::incoming_connection(), res)))
            });
            if result.is_err() {
                // An error only occurs when the target process is not alive. At that point we can
                // safely stop.
                return;
            }
        }
    });

    ret_token
}

#[nif]
fn endpoint_id(er: ResourceArc<EndpointResource>) -> ResourceArc<PublicKeyResource> {
    ResourceArc::new(PublicKeyResource(er.endpoint.id()))
}

#[nif]
fn endpoint_addr(er: ResourceArc<EndpointResource>) -> ResourceArc<EndpointAddrResource> {
    ResourceArc::new(EndpointAddrResource(er.endpoint.addr()))
}

#[nif(schedule = "DirtyIo")]
fn endpoint_connect<'a>(
    env: Env<'a>,
    er: ResourceArc<EndpointResource>,
    addr: ResourceArc<EndpointAddrResource>,
    alpn: Binary<'a>,
) -> Term<'a> {
    let endpoint = er.endpoint.clone();
    let addr = addr.0.clone();

    let result = RUNTIME.block_on(async move { endpoint.connect(addr, alpn.as_slice()).await });
    match result {
        Ok(con) => (atoms::ok(), ResourceArc::new(ConnectionResource(con))).encode(env),
        Err(err) => (atoms::error(), err.to_string()).encode(env),
    }
}

#[nif]
fn secret_key_generate() -> ResourceArc<SecretKeyResource> {
    ResourceArc::new(SecretKeyResource(SecretKey::generate(&mut rand::rng())))
}

#[nif]
fn secret_key_to_public(sk: ResourceArc<SecretKeyResource>) -> ResourceArc<PublicKeyResource> {
    ResourceArc::new(PublicKeyResource(sk.0.public()))
}

#[nif]
fn public_key_to_string(pk: ResourceArc<PublicKeyResource>) -> String {
    pk.0.to_string()
}

#[nif]
fn public_key_from_string(env: Env, s: String) -> Term {
    match PublicKey::from_str(&s) {
        Ok(pk) => (atoms::ok(), ResourceArc::new(PublicKeyResource(pk))).encode(env),
        Err(e) => (atoms::error(), e.to_string()).encode(env),
    }
}

#[nif]
fn public_key_to_addr(pk: ResourceArc<PublicKeyResource>) -> ResourceArc<EndpointAddrResource> {
    ResourceArc::new(EndpointAddrResource(EndpointAddr::new(pk.0)))
}
