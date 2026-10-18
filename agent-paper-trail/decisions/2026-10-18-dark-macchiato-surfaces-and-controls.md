---
status: Accepted
date: 2026-10-18
supersedes: []
superseded_by: ""
---

# Dark Macchiato surfaces and controls

## Context

Dark Mauve accents over neutral system backgrounds do not provide the intended Catppuccin Macchiato appearance. The dark surface direction now follows the [official palette](https://catppuccin.com/palette/) and the website's dark text on Mauve controls.

## Decision

Continue following system light/dark appearance. Keep native surface colours in Light. In Dark, use Macchiato Base `#24273A` for file panels and inset previews, Mantle `#1E2030` for headers and Details, and Crust `#181926` for the window frame. Dividers use Surface 0 `#363A4F` where the app owns their drawing.

Retain Mauve `#C6A0F6`. Enabled Mauve-filled buttons and the selected Preview/Edit segment use Base text in Dark; this pair has calculated 6.84:1 contrast. Light retains the existing darker Mauve and native control presentation. Preserve native keyboard/focus, accessibility and disabled-state behaviour. Use public native styling/drawing APIs.

This refines the surface treatment in the accepted UI design. Browser layout, the separate muted row selection and logo geometry remain governed by their existing decisions. System-owned panels retain their native presentation; the browser window, app-owned sheets and controls use the shared roles.

## Alternatives and consequences

Keeping system grey surfaces preserves the earlier implementation but misses the chosen dark palette. Recolouring every system panel would require broader custom UI. Shared app-owned colour roles give the requested dark appearance while preserving system-owned panels and Light.

Validate appearance changes in both directions, neutral and selected states, enlarged/narrow layouts, keyboard/focus, VoiceOver and increased contrast. Record executed checks separately from manual acceptance in the task evidence.
