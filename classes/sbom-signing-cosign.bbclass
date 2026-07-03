# Cosign Backend for SBOM Signing
#
# Signs SBOMs using Sigstore Cosign with local keys 
# Keyless (Fulcio) is not supported.

# Conditional dependency on cosign-native
DEPENDS:append = " ${@'cosign-native' if d.getVar('SBOM_SIGN_ENABLED') == '1' and d.getVar('SBOM_SIGN_BACKEND') == 'cosign' else ''}"

# Cosign-specific variables
SBOM_SIGN_COSIGN_KEY_PATH ??= "${TOPDIR}/keys/cosign.key"
SBOM_SIGN_COSIGN_PASSWORD_FILE ??= ""
SBOM_SIGN_COSIGN_EXTRA_ARGS ??= ""

SBOM_SIGN_COSIGN_EXTRA_ARGS ??= ""
def sbom_signing_cosign_validate(d):
    """Validate Cosign configuration"""
    import os

    key_path = d.getVar('SBOM_SIGN_COSIGN_KEY_PATH')

    if not key_path:
        bb.fatal("SBOM_SIGN_COSIGN_KEY_PATH not set")

    key_path_expanded = d.expand(key_path)

    if not os.path.exists(key_path_expanded):
        bb.fatal(f"Cosign key not found: {key_path_expanded}")

    bb.debug(1, f"Using Cosign key: {key_path_expanded}")
    return True

def sbom_signing_cosign_sign(filepath, d):
    """Sign SBOM file with Cosign"""
    import os
    import subprocess

    extra_args = d.getVar('SBOM_SIGN_COSIGN_EXTRA_ARGS') or ''
    sig_file = f"{filepath}.sig"

    cosign_bin = os.path.join(d.getVar('STAGING_BINDIR_NATIVE'), 'cosign')
    if not os.path.exists(cosign_bin):
        raise Exception(f"cosign binary not found at {cosign_bin}")

    key_path = d.expand(d.getVar('SBOM_SIGN_COSIGN_KEY_PATH'))
    cmd_env = os.environ.copy()

    for var in ['http_proxy', 'https_proxy', 'HTTP_PROXY', 'HTTPS_PROXY', 'no_proxy', 'NO_PROXY']:
        val = d.getVar(var) or os.environ.get(var)
        if val:
            cmd_env[var] = val

    password_file = d.getVar('SBOM_SIGN_COSIGN_PASSWORD_FILE')
    if password_file:
        password_file_expanded = d.expand(password_file)
        if os.path.exists(password_file_expanded):
            with open(password_file_expanded, 'r') as f:
                cmd_env['COSIGN_PASSWORD'] = f.read().strip()
    else:
        cmd_env['COSIGN_PASSWORD'] = ""

    cmd_args = [
        cosign_bin,
        'sign-blob',
        '--yes',
        '--key', key_path,
        '--bundle', sig_file,
    ]

    if d.getVar('SBOM_SIGN_COSIGN_AIR_GAPPED_ENABLED') == '1':
        cmd_args.extend(['--tlog-upload=false', '--use-signing-config=false'])

    if extra_args:
        cmd_args.extend(extra_args.split())

    cmd_args.append(filepath)

    try:
        bb.note("Running: {}".format(" ".join(cmd_args)))
        bb.note("Env: {}".format(" ".join(cmd_env)))
        bb.process.run(cmd_args, env=cmd_env)
    except bb.process.ExecutionError as e:
        raise Exception(f"Cosign signing failed: {e}")

    if not os.path.exists(sig_file):
        raise Exception(f"Signature file not created: {sig_file}")

    return sig_file

# Run validation at parse time
python __anonymous() {
    if d.getVar('SBOM_SIGN_ENABLED') == '1' and d.getVar('SBOM_SIGN_BACKEND') == 'cosign':
        if d.getVar('IMAGE_BASENAME'):
            sbom_signing_cosign_validate(d)
}
