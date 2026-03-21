use iroh::endpoint::{Connection, Incoming, RecvStream, SendStream, VarInt};
use rustler::{
    nif, resource_impl, Atom, Binary, Encoder, Env, LocalPid, OwnedEnv, Resource, ResourceArc, Term,
};
use tokio::select;
use tokio_util::sync::CancellationToken;

use crate::{
    atoms,
    stream::{RecvStreamResource, SendStreamResource},
    CancelToken, RUNTIME,
};

pub struct ConnectionResource(pub Connection);

#[resource_impl]
impl Resource for ConnectionResource {}

pub struct IncomingResource {
    pub incoming: parking_lot::Mutex<Option<Incoming>>,
}

#[resource_impl]
impl Resource for IncomingResource {
    fn destructor(self, _env: Env<'_>) {
        let Some(incoming) = self.incoming.lock().take() else {
            return;
        };
        incoming.ignore();
    }
}

#[nif(schedule = "DirtyIo")]
fn incoming_accept(env: Env, ir: ResourceArc<IncomingResource>) -> Term {
    RUNTIME.block_on(async move {
        let incoming = ir.incoming.lock().take();
        let Some(incoming) = incoming else {
            panic!("trying to accept already handled incoming connection");
        };

        match incoming.accept() {
            Ok(conn) => match conn.await {
                Ok(conn) => (atoms::ok(), ResourceArc::new(ConnectionResource(conn))).encode(env),
                Err(e) => (atoms::error(), e.to_string()).encode(env),
            },
            Err(e) => (atoms::error(), e.to_string()).encode(env),
        }
    })
}

#[nif]
fn incoming_refuse(ir: ResourceArc<IncomingResource>) {
    let incoming = ir.incoming.lock().take();
    let Some(incoming) = incoming else {
        panic!("trying to refuse already handled incoming connection");
    };

    incoming.refuse();
}

#[nif]
fn incoming_ignore(ir: ResourceArc<IncomingResource>) {
    let incoming = ir.incoming.lock().take();
    let Some(incoming) = incoming else {
        panic!("trying to ignore already handled incoming connection");
    };

    incoming.ignore();
}

#[nif(schedule = "DirtyIo")]
fn connection_open_uni(env: Env, cr: ResourceArc<ConnectionResource>) -> Term {
    let res = RUNTIME.block_on(async { cr.0.open_uni().await.map_err(|e| e.to_string()) });

    match res {
        Ok(send) => {
            let send_res = ResourceArc::new(SendStreamResource(tokio::sync::Mutex::new(send)));
            (atoms::ok(), send_res).encode(env)
        }
        Err(e) => (atoms::error(), e).encode(env),
    }
}

#[nif(schedule = "DirtyIo")]
fn connection_open_bi(env: Env, cr: ResourceArc<ConnectionResource>) -> Term {
    let res = RUNTIME.block_on(async { cr.0.open_bi().await.map_err(|e| e.to_string()) });

    match res {
        Ok((send, recv)) => {
            let send_res = ResourceArc::new(SendStreamResource(tokio::sync::Mutex::new(send)));
            let recv_res = ResourceArc::new(RecvStreamResource(tokio::sync::Mutex::new(recv)));
            (atoms::ok(), (send_res, recv_res)).encode(env)
        }
        Err(e) => (atoms::error(), e).encode(env),
    }
}

#[nif]
fn connection_close(cr: ResourceArc<ConnectionResource>, error_code: u32, reason: Binary) {
    cr.0.close(VarInt::from_u32(error_code), &reason);
}

#[nif]
fn connection_is_closed(cr: ResourceArc<ConnectionResource>) -> bool {
    cr.0.close_reason().is_some()
}

#[nif]
fn connection_subscribe(
    cr: ResourceArc<ConnectionResource>,
    subject: Term,
) -> ResourceArc<CancelToken> {
    let env = OwnedEnv::new();

    let (s, pid, reference): (Atom, LocalPid, Term) = subject.decode().unwrap();
    assert_eq!(s, atoms::subject());

    let reference = env.save(reference);
    let endpoint = cr.0.clone();

    let token = CancellationToken::new();
    let ret_token = CancelToken::wrap(token.clone());

    RUNTIME.spawn(async move {
        let env = env;
        loop {
            enum Event {
                UniStream(RecvStream),
                BiStream(SendStream, RecvStream),
                Closed,
            }

            let event: Event = select! {
                biased;
                _ = token.cancelled() => return,
                incoming = endpoint.accept_uni() => match incoming {
                    Ok(recv) => Event::UniStream(recv),
                    Err(_err) => Event::Closed,
                },
                incoming = endpoint.accept_bi() => match incoming {
                    Ok((send, recv)) => Event::BiStream(send, recv),
                    Err(_err) => Event::Closed,
                },
            };

            let result = match event {
                Event::UniStream(recv_stream) => {
                    let recv_res =
                        ResourceArc::new(RecvStreamResource(tokio::sync::Mutex::new(recv_stream)));

                    env.run(|env| {
                        let reference = reference.load(env);
                        env.send(&pid, (reference, (atoms::uni_stream(), recv_res)))
                    })
                }
                Event::BiStream(send_stream, recv_stream) => {
                    let send_res =
                        ResourceArc::new(SendStreamResource(tokio::sync::Mutex::new(send_stream)));
                    let recv_res =
                        ResourceArc::new(RecvStreamResource(tokio::sync::Mutex::new(recv_stream)));

                    env.run(|env| {
                        let reference = reference.load(env);
                        env.send(&pid, (reference, (atoms::bi_stream(), send_res, recv_res)))
                    })
                }
                Event::Closed => {
                    // TODO: send the error/reason in the close event
                    _ = env.run(|env| {
                        let reference = reference.load(env);
                        env.send(&pid, (reference, atoms::closed()))
                    });
                    return;
                }
            };

            if result.is_err() {
                // An error only occurs when the target process is not alive. At that point we can
                // safely stop.
                return;
            }
        }
    });

    ret_token
}
