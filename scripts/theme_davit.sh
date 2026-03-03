#!/usr/bin/env bash
#==============================================================================:
# File:          theme_davit.sh
# Description:   DAVIT standard terminal color theme definitions
# Author:        David Mullins & ScriptOps Team
# License:       MIT
# Version:       0.1.0
# Created:       2025-11-02
# UUID:          4b28d4f0-e54d-46b0-8e67-e7d78d13f5aa
# $Id: code-style v0.3.1 2025/10/01 10:46:54
#==============================================================================:

#------------------------------------------------------------------------------:
# THEME CONFIGURATION
#------------------------------------------------------------------------------:
#   DAVIT_THEME_MODE :  dark | light | minimal
#   Auto-detect dark if undefined and stdout is a TTY.
#------------------------------------------------------------------------------:

if [[ -z "${DAVIT_THEME_MODE}" ]]; then
  if [[ -t 1 ]]; then
    DAVIT_THEME_MODE="dark"
  else
    DAVIT_THEME_MODE="minimal"
  fi
fi

# ANSI reset (always defined)
DAVIT_COLOR_RESET="\033[0m"

#------------------------------------------------------------------------------:
# DARK MODE
#------------------------------------------------------------------------------:
if [[ "$DAVIT_THEME_MODE" == "dark" ]]; then
  DAVIT_COLOR_INFO="\033[1;32m"       # bright green
  DAVIT_COLOR_WARN="\033[1;33m"       # yellow
  DAVIT_COLOR_ERROR="\033[1;31m"      # red
  DAVIT_COLOR_DEBUG="\033[1;36m"      # cyan
  DAVIT_COLOR_CRITICAL="\033[97;41m" # white on red bg
  DAVIT_COLOR_HEADER="\033[1;34m"     # blue
  DAVIT_COLOR_SUCCESS="\033[1;32m"    # green
  DAVIT_COLOR_HIGHLIGHT="\033[1;35m"  # magenta
fi

#------------------------------------------------------------------------------:
# LIGHT MODE
#------------------------------------------------------------------------------:
if [[ "$DAVIT_THEME_MODE" == "light" ]]; then
  DAVIT_COLOR_INFO="\033[0;32m"
  DAVIT_COLOR_WARN="\033[0;33m"
  DAVIT_COLOR_ERROR="\033[0;31m"
  DAVIT_COLOR_DEBUG="\033[0;36m"
  DAVIT_COLOR_CRITICAL="\033[0;37;41m"
  DAVIT_COLOR_HEADER="\033[0;34m"
  DAVIT_COLOR_SUCCESS="\033[0;32m"
  DAVIT_COLOR_HIGHLIGHT="\033[0;35m"
fi

#------------------------------------------------------------------------------:
# MINIMAL (no color)
#------------------------------------------------------------------------------:
if [[ "$DAVIT_THEME_MODE" == "minimal" ]]; then
  for C in INFO WARN ERROR DEBUG CRITICAL HEADER SUCCESS HIGHLIGHT RESET; do
    eval "DAVIT_COLOR_${C}=''"
  done
fi
#==============================================================================:
