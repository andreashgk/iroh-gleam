.PHONY: build test clean

build:
	./native/iroh_nif/build.sh
	gleam build

test: build
	gleam test

clean:
	rm -rf priv/libiroh_nif.so
	cd native/iroh_nif && cargo clean
	gleam clean
