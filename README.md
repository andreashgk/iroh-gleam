# iroh-gleam

Gleam bindings to [iroh](https://www.iroh.computer/).

Iroh is a peer-to-peer networking stack written in rust, built on QUIC.
From the [iroh repository](https://github.com/n0-computer/iroh):
> Iroh gives you an API for dialing by public key. You say “connect to that phone”, iroh will find
> & maintain the fastest connection for you, regardless of where it is.

Not all functionality has been implemented yet. If you need something, feel free to open an issue or
PR.

## Usage

> [!CAUTION]
> This package cannot currently be considered production ready. Use at your own risk.

**Requirements:**
- A gleam project with BEAM as target
- A recent version of the rust toolchain

Add this repository as a submodule using
```sh
git submodule add https://github.com/andreashgk/iroh-gleam submodules/iroh-gleam # Example path
```
Also add it to your gleam.toml:
```toml
iroh = { path = "./submodules/iroh-gleam" }
```
Before running gleam for the first time you will need to compile the native library first.
A shell script is included for this:
```sh
cd ./submodules/iroh-gleam && ./native/iroh_nif/build.sh
```

You can now use iroh from gleam!

## Examples

Examples can be found at [examples](examples/).
