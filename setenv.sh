# Wrapper around Qualcomm setup-environment (set_bb_env.sh).
#
# Usage (must be sourced):
#   MACHINE=<machine> DISTRO=<distro> [DL_DIR=<path>] [EXTRALAYERS=...] \
#     BUILDDIR= . ./setenv.sh <builddir-relative-name>
#
# If DL_DIR is set in the environment, update <builddir>/conf/site.conf after
# setup-environment (which always writes DL_DIR=${WS}/downloads, and skips
# rewrite when the build dir already exists).
#
# Example:
#   MACHINE=qcs9075-iq-9075-evk DISTRO=qcom-wayland \
#     DL_DIR=/home/joelai/02_dev2/yocto-dl BUILDDIR= \
#     . ./setenv.sh build_yocto_iq9075evk

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	echo "Error: source this script, e.g. '. ./setenv.sh <builddir>'" >&2
	exit 1
fi

_SETENV_ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
_SETENV_DL_DIR=${DL_DIR-}

# shellcheck disable=SC1091
. "${_SETENV_ROOT}/setup-environment" "$@" || return $?

# oe-init-build-env cds into BUILDDIR and leaves BUILDDIR absolute.
_SETENV_SITECONF="${BUILDDIR}/conf/site.conf"
if [ -n "${_SETENV_DL_DIR}" ] && [ -f "${_SETENV_SITECONF}" ]; then
	mkdir -p "${_SETENV_DL_DIR}"
	if ! grep -qx "DL_DIR = \"${_SETENV_DL_DIR}\"" "${_SETENV_SITECONF}"; then
		sed -i "s|^DL_DIR = .*|DL_DIR = \"${_SETENV_DL_DIR}\"|" "${_SETENV_SITECONF}"
		echo "site.conf: DL_DIR = \"${_SETENV_DL_DIR}\""
	fi
fi

unset _SETENV_ROOT _SETENV_DL_DIR _SETENV_SITECONF
