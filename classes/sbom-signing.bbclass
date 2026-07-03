# SBOM Signing Core Orchestration Class
#
# Backend-agnostic SBOM signing framework. Dispatches to signing backends
# (cosign & gpg) based on SBOM_SIGN_BACKEND variable.

# Inherit backend class based on SBOM_SIGN_BACKEND
#inherit ${@'sbom-signing-' + d.getVar('SBOM_SIGN_BACKEND') if d.getVar('SBOM_SIGN_ENABLED') == '1' and d.getVar('IMAGE_BASENAME') else ''}

inherit sbom-signing-cosign
inherit sbom-signing-gpg

# Configuration validation
def sbom_signing_validate_config(d):
    """Validate configuration at parse time"""
    backend = d.getVar('SBOM_SIGN_BACKEND')
    valid_backends = ['cosign', 'gpg']

    if backend not in valid_backends:
        bb.fatal(f"Invalid SBOM_SIGN_BACKEND '{backend}'. Valid: {', '.join(valid_backends)}")

    # Backend-specific validation called by backend class
    return True

def sbom_signing_sign_file(filepath, d):
    """Dispatch to backend-specific signing function"""
    backend = d.getVar('SBOM_SIGN_BACKEND')

    if backend == 'cosign':
        return sbom_signing_cosign_sign(filepath, d)
    elif backend == 'gpg':
        return sbom_signing_gpg_sign(filepath, d)
    else:
        bb.fatal(f"Unknown backend: {backend}")


python do_sbom_sign() {
    """Sign SBOM files after generation"""
    if d.getVar('SBOM_SIGN_ENABLED') != '1':
        bb.note("SBOM signing disabled (SBOM_SIGN_ENABLED != '1')")
        return

    if not d.getVar('IMAGE_BASENAME'):
        bb.note("Skipping SBOM signing (not an image recipe)")
        return

    sbom_path = d.expand("${DEPLOY_DIR_IMAGE}/${IMAGE_LINK_NAME}.spdx.json")

    if not sbom_path:
        bb.warn("No SBOM files found to sign")
        return

    try:
        sig_file = sbom_signing_sign_file(sbom_path, d)
        bb.note(f"Signed {os.path.basename(sbom_path)} -> {os.path.basename(sig_file)}")
    except Exception as e:
        error_msg = f"Failed to sign {sbom_path}: {e}"
        if d.getVar('SBOM_SIGN_STRICT') == '1':
            bb.fatal(error_msg)
        else:
            bb.warn(error_msg)

}


# Setup task at parse time
python __anonymous() {
    """Setup task dependencies at parse time"""
    import os

    # Only apply to image recipes when signing enabled
    if d.getVar('SBOM_SIGN_ENABLED') != '1':
        return

    if not d.getVar('IMAGE_BASENAME'):
        return

    # Validate config
    sbom_signing_validate_config(d)

    # Add task to dependency chain
    # SBOM written during do_image_complete for images
    #bb.build.addtask('do_sbom_sign', 'do_build', 'do_image_complete', d)
    # do_create_spdx must complete before signing
    #bb.build.addtask('do_sbom_sign', 'do_build', 'do_create_spdx', d)
    bb.build.addtask('do_sbom_sign', 'do_build', 'do_create_image_sbom_spdx', d)

    d.appendVarFlag('do_sbom_sign', 'depends', ' cosign-native:do_populate_sysroot')
}

# addtask do_sbom_sign after do_create_image_sbom_spdx before do_build
#
# SSTATETASKS += "do_sbom_sign"
# do_sbom_sign[cleandirs] = "${SBOM_CVE_CHECK_DEPLOYDIR}"
# do_sbom_sign[sstate-inputdirs] = "${SBOM_CVE_CHECK_DEPLOYDIR}"
# do_sbom_sign[sstate-outputdirs] = "${DEPLOY_DIR_IMAGE}"
# do_sbom_sign[depends] += " \
#     cosign-native:do_populate_sysroot \
#     ${SBOM_SIGN_EXTRA_DEPENDENCIES} \
# "
#
# python do_sbom_sign_setscene() {
#     sstate_setscene(d)
# }
# addtask do_sbom_sign_setscene

# Task metadata
do_sbom_sign[nostamp] = "1"
do_sbom_sign[vardepsexclude] = "DATETIME"
do_sbom_sign[network] = "1"