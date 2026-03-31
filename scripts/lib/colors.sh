#!/bin/bash
# Shared color library for homelab scripts
# Source this file from other scripts: source "$(dirname "${BASH_SOURCE[0]}")/lib/colors.sh"

# Disable colors if stdout is not a terminal
if [[ ! -t 1 ]]; then
    _NO_COLOR=1
fi

# Disable colors if NO_COLOR env var is set (https://no-color.org/)
if [[ -n "${NO_COLOR:-}" ]]; then
    _NO_COLOR=1
fi

# Color variables
if [[ -z "${_NO_COLOR:-}" ]]; then
    _C_RESET='\033[0m'
    _C_BOLD='\033[1m'
    _C_RED='\033[0;31m'
    _C_GREEN='\033[0;32m'
    _C_YELLOW='\033[0;33m'
    _C_BLUE='\033[0;34m'
    _C_MAGENTA='\033[0;35m'
    _C_CYAN='\033[0;36m'
else
    _C_RESET=''
    _C_BOLD=''
    _C_RED=''
    _C_GREEN=''
    _C_YELLOW=''
    _C_BLUE=''
    _C_MAGENTA=''
    _C_CYAN=''
fi

info() {
    echo -e "  ${_C_BLUE}[INFO]${_C_RESET} $*"
}

success() {
    echo -e "  ${_C_GREEN}[OK]${_C_RESET} $*"
}

error() {
    echo -e "  ${_C_RED}[ERROR]${_C_RESET} $*"
}

warn() {
    echo -e "  ${_C_YELLOW}[WARN]${_C_RESET} $*"
}

step() {
    echo -e "  ${_C_MAGENTA}[$1/$2]${_C_RESET} $3"
}

header() {
    echo -e "${_C_BOLD}${_C_CYAN}=== $* ===${_C_RESET}"
}

msg() {
    echo -e "$*"
}

bold() {
    echo -e "${_C_BOLD}$*${_C_RESET}"
}
