# direnv-lib

Small personal direnv library for `~/.config/direnv`.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/declnix/direnv-lib/main/install.sh | bash
```

Or from a local checkout:

```sh
./install.sh
```

The installer only creates or reuses Git metadata at `~/.config/direnv/.git`.
It does not remove or overwrite files that already exist in `~/.config/direnv`.
Generated `nix-direnv` files are ignored.

After installation, manage the repository explicitly:

```sh
git -C "$HOME/.config/direnv" status
```

## Disclaimer

⚠️ **This is a personal hobby project** developed in spare time.

- The API surface is **unstable** and may change without notice
- Built with **AI assistance**
- No support commitment or warranty
