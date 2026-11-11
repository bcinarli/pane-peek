---
task: ruby
verdict: Pending
closed: ""
---

# Ruby

`.rb`, `.rake`, `.gemspec` and `.ru` files and the conventional Ruby filenames use a focused Ruby scanner: reserved keywords, `nil`/`true`/`false`/`self`, symbols and hash labels, quoted and percent literals with `#{…}` interpolation as references, queued heredoc bodies including `<<~` and `<<-`, regular expressions and percent literals only where an operand may start, variables as references, validated numbers, `#` comments and column-zero `=begin`/`=end`. `Gemfile.lock` stays plain and `.gemrc` stays YAML. Not published.

No new token kinds or colours. Limits: `__END__` data sections, labels inside ternaries and `<<CAPS` after a local variable stay approximate; interpolation bodies take one reference colour. Signed-app Preview/Edit, draft and BOM/CRLF Save checks remain for manual review.
