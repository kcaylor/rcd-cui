# common

## What This Does

This role validates that every host has an explicit cui_zone before any control-specific role runs.
It fails immediately when zone assignment is missing or invalid so controls are never applied ambiguously.
