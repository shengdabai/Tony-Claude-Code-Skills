#!/usr/bin/env bash
# Shared by the local structure validator and CI frontmatter checks.

is_skill_collection() {
  # Explicit vendored collection roots (verified against their READMEs).
  # Do not infer a collection merely because its SKILL.md is missing.
  case "$1" in
    _repos|_collections|0|JamesPrial-github-skills|d-kimuson-dotfiles|\
    rghamilton3-dotfiles|rsmdt-the-startup|superpowers|\
    travisvn-awesome-claude-skills|wshobson-agents) return 0 ;;
    *) return 1 ;;
  esac
}
