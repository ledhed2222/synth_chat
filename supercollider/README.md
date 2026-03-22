This folder contains all the stuff necessary to set up SuperCollider in a docker container such that we can read from it.

It has a single SuperCollider code file, `boot_scsynth.scd` that handles scsynth server initialization and defines some functions that should be used by actual application code.

The application SuperCollider code is all in `priv/supercollider`.

Because of boot timing, it's important that all application SuperCollider code is wrapped in the `~whenReady` function, which is defined in `boot_scsynth.scd`.
