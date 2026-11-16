---
task: ruby
verdict: Pending
closed: ""
---

# Ruby

`.rb`, `.rake`, `.gemspec` and `.ru` files and the conventional Ruby filenames use a focused Ruby scanner: reserved keywords, `nil`/`true`/`false`/`self`, symbols and hash labels, quoted and percent literals with `#{…}` interpolation as references, queued heredoc bodies including `<<~` and `<<-`, regular expressions and percent literals only where an operand may start, variables as references, validated numbers, `#` comments and column-zero `=begin`/`=end`. `Gemfile.lock` stays plain and `.gemrc` stays YAML. Heredoc bodies retain labels with trailing whitespace and continued lines; multiline member calls and quoted hash-label values preserve their lexical context. [PR #200](https://github.com/bcinarli/pane-peek/pull/200).

No new token kinds or colours. Limits: `__END__` data sections, labels inside ternaries and `<<CAPS` after a local variable stay approximate; interpolation bodies take one reference colour. Signed-app functional review passed, including draft retention, Undo/Redo and byte-preserving Save. VoiceOver and other affected accessibility checks passed in manual review. Manual acceptance, including the measured performance cost below, remains pending.

Matched signed arm64 Release trials against accepted main `41573f9` on Apple M5 / macOS 27.0.1 / Xcode 27.1 found no material shared-path regression; three measured trials after warm-up gave median bundle size 8.609 → 8.657 MiB and idle RSS 99.5 → 99.5 MiB, with median idle CPU below the sampler's 0.33%-of-one-core resolution. The ten-case native workload changed from 2.67 to 2.88 s elapsed, 1.47 to 1.70 s CPU and 127.0 to 135.6 MiB sampled peak RSS; the new 960 KB language case opened in 112 ms (110–112), completed three recoloured insertions in 250 ms (248–253) and three Preview/Edit cycles in 12 ms, versus 38/92/10 ms for baseline plain text. Opening, editing and switching are native component timings using in-memory fixtures, excluding filesystem reads and browser selection overhead; CPU/RSS cover the app process only.
