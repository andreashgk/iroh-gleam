use iroh::endpoint::{RecvStream, SendStream};
use rustler::{nif, resource_impl, Binary, Encoder, Env, NewBinary, Resource, ResourceArc, Term};

use crate::{atoms, RUNTIME};

pub struct SendStreamResource(pub tokio::sync::Mutex<SendStream>);

#[resource_impl]
impl Resource for SendStreamResource {}

pub struct RecvStreamResource(pub tokio::sync::Mutex<RecvStream>);

#[resource_impl]
impl Resource for RecvStreamResource {}

#[nif(schedule = "DirtyIo")]
fn stream_write<'a>(
    env: Env<'a>,
    sr: ResourceArc<SendStreamResource>,
    data: Binary<'a>,
) -> Term<'a> {
    let res = RUNTIME.block_on(async {
        let mut lock = sr.0.lock().await;
        lock.write_all(&data).await.map_err(|e| e.to_string())
    });

    match res {
        Ok(_) => (atoms::ok(), atoms::nil()).encode(env),
        Err(e) => (atoms::error(), e).encode(env),
    }
}

#[nif(schedule = "DirtyIo")]
fn stream_finish(env: Env, sr: ResourceArc<SendStreamResource>) -> Term {
    let res = RUNTIME.block_on(async {
        let mut lock = sr.0.lock().await;
        lock.finish().map_err(|e| e.to_string())
    });

    match res {
        Ok(_) => (atoms::ok(), atoms::nil()).encode(env),
        Err(e) => (atoms::error(), e).encode(env),
    }
}

#[nif(schedule = "DirtyIo")]
fn stream_stop(env: Env, sr: ResourceArc<RecvStreamResource>, error_code: u32) -> Term {
    let res = RUNTIME.block_on(async {
        let mut lock = sr.0.lock().await;
        lock.stop(error_code.into())
    });

    match res {
        Ok(_) => (atoms::ok(), atoms::nil()).encode(env),
        Err(_) => (atoms::error(), atoms::nil()).encode(env),
    }
}

#[nif(schedule = "DirtyIo")]
fn stream_read(env: Env, sr: ResourceArc<RecvStreamResource>, len: usize) -> Term {
    let res = RUNTIME.block_on(async {
        let mut binary = NewBinary::new(env, len);
        let mut lock = sr.0.lock().await;
        let n = match lock.read(&mut binary).await {
            Ok(Some(n)) => n,
            Ok(None) => 0,
            Err(e) => return Err(e.to_string()),
        };
        Ok((binary, n))
    });

    match res {
        Ok((buf, n)) => {
            let binary = Binary::from(buf);
            let binary = binary.make_subbinary(0, n).expect("n <= len(binary)");
            (atoms::ok(), binary).encode(env)
        }
        Err(e) => (atoms::error(), e).encode(env),
    }
}

#[nif(schedule = "DirtyIo")]
fn stream_read_exact(env: Env, sr: ResourceArc<RecvStreamResource>, len: usize) -> Term {
    let res = RUNTIME.block_on(async move {
        let mut binary = NewBinary::new(env, len);
        let mut lock = sr.0.lock().await;
        match lock.read_exact(&mut binary).await {
            Ok(()) => {}
            Err(e) => return Err(e.to_string()),
        }
        Ok(binary)
    });

    match res {
        Ok(buf) => {
            let binary = Binary::from(buf);
            (atoms::ok(), binary).encode(env)
        }
        Err(e) => (atoms::error(), e).encode(env),
    }
}

#[nif(schedule = "DirtyIo")]
fn stream_read_to_end(env: Env, sr: ResourceArc<RecvStreamResource>, max_len: usize) -> Term {
    let res = RUNTIME.block_on(async move {
        let mut lock = sr.0.lock().await;
        match lock.read_to_end(max_len).await {
            Ok(buf) => Ok(buf),
            Err(e) => Err(e.to_string()),
        }
    });

    match res {
        Ok(buf) => {
            let mut binary = NewBinary::new(env, buf.len());
            binary.copy_from_slice(&buf);
            (atoms::ok(), Binary::from(binary)).encode(env)
        }
        Err(e) => (atoms::error(), e).encode(env),
    }
}
