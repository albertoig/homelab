#!/bin/bash
# Shared color library for homelab scripts
# Source this file from other scripts: source "$(dirname "${BASH_SOURCE[0]}")/../lib/colors.sh"

# ── Gum palette (256-color codes for --foreground / --border-foreground) ──────

GUM_PRIMARY=212     # pink   — main accent, env labels, success boxes
GUM_SECONDARY=99    # purple — section headers, box borders
GUM_ACCENT=214      # orange — prompts, highlighted keys, warnings
GUM_SUCCESS=2       # green  — success borders and checkmarks
GUM_ERROR=1         # red    — error borders, failure marks
GUM_MUTED=240       # gray   — faint descriptions, subtitles
GUM_HEADER=45       # cyan   — banner block letters (retro CRT)
GUM_HEADER_SUB=214  # amber  — banner tagline and byline

# ── Gum inline-text helpers ───────────────────────────────────────────────────
# Usage: gum_primary --bold "some text"
#        gum_secondary "Environment: $ENV"

gum_primary()   { gum style --foreground "$GUM_PRIMARY"   "$@"; }
gum_secondary() { gum style --foreground "$GUM_SECONDARY" "$@"; }
gum_accent()    { gum style --foreground "$GUM_ACCENT"    "$@"; }
gum_muted()     { gum style --foreground "$GUM_MUTED" --faint "$@"; }
gum_success()   { gum style --foreground "$GUM_SUCCESS"   "$@"; }
gum_error()     { gum style --foreground "$GUM_ERROR"     "$@"; }

# ── Log functions ─────────────────────────────────────────────────────────────

info()    { gum log --level info  "$*"; }
warn()    { gum log --level warn  "$*"; }
error()   { gum log --level error "$*"; }
success() { gum log --level info  "✓ $*"; }
header()  { gum_secondary --bold "=== $* ==="; }
step()    { gum_secondary "  [$1/$2] $3"; }
bold()    { gum_primary --bold "$*"; }
msg()     { printf '%s\n' "$*"; }
