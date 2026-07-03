# meta-sbom-signing

A Yocto layer that signs SPDX SBOM files after they are generated during a build. Supports cosign (Sigstore) backends.

Compatible with Yocto master (wrynose).

## Setup

Add the layer to your build:

```bash
git clone https://github.com/yogeshhegde/meta-sbom-signing.git
bitbake-layers add-layer meta-sbom-signing
```

Generate a key pair:

```bash
cosign generate-key-pair
mkdir -p build/keys
mv cosign.key cosign.pub build/keys/
```

Add to `conf/local.conf`:

```bash
INHERIT += "sbom-signing"
SBOM_SIGN_ENABLED = "1"
SBOM_SIGN_BACKEND = "cosign"
SBOM_SIGN_COSIGN_KEY_PATH = "${TOPDIR}/keys/cosign.key"
SBOM_SIGN_COSIGN_PASSWORD_FILE = "${TOPDIR}/tmp/pass.txt"
```

Build as normal. A `.spdx.json.sig` bundle file will appear alongside the SBOM in `tmp/deploy/images/<machine>/`.

## Verification

```bash
cosign verify-blob \
    --key keys/cosign.pub \
    --bundle tmp/deploy/images/<machine>/<image>.spdx.json.sig \
    tmp/deploy/images/<machine>/<image>.spdx.json
```

When `SBOM_SIGN_COSIGN_AIR_GAPPED_ENABLED` is used, the verification command line is:

```bash
cosign verify-blob \
    --insecure-ignore-tlog=true \
    --insecure-ignore-sct=true \
    --key keys/cosign.pub \
    --bundle tmp/deploy/images/<machine>/<image>.spdx.json.sig \
    tmp/deploy/images/<machine>/<image>.spdx.json
```

## Configuration

**Cosign (default)**

Note: by default cosign needs to Internet connection for fetching signing
metadata. The option `SBOM_SIGN_COSIGN_AIR_GAPPED_ENABLED` exists to avoid
any Internet dependency.

| Variable | Default | Description |
|---|---|---|
| `SBOM_SIGN_COSIGN_KEY_PATH` | `${TOPDIR}/keys/cosign.key` | Path to private key |
| `SBOM_SIGN_COSIGN_PASSWORD_FILE` | | File containing key password |
| `SBOM_SIGN_COSIGN_AIR_GAPPED_ENABLED` | Sign without external connectivity |
| `SBOM_SIGN_COSIGN_EXTRA_ARGS` | | Optional Extra arguments for `cosign sign-blob` |

**GPG**

Note: the GPG backend is not yet implemented.

**General**

| Variable | Default | Description |
|---|---|---|
| `SBOM_SIGN_ENABLED` | `0` | Set to `1` to enable signing |
| `SBOM_SIGN_BACKEND` | `cosign` | `cosign` or `gpg` |
| `SBOM_SIGN_STRICT` | `1` | Fail the build on error (`1`) or warn and continue (`0`) |

## License

MIT
