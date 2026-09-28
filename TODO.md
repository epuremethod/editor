# TODO

## Markdown input helpers

Decide whether the editor offers the usual Markdown shortcuts while typing.
One option is a function the host injects on `make`. It sees the input and
returns a transform. `|` marks the caret.

- `* |` turns the block into an item.
- `whatever **|` becomes `whatever **|**`, with the caret between the
  markers.
- `# bob` turns the block into a heading.
- `---` inserts a horizontal rule.

## Code blocks

Decide how to handle a fenced code block, opened with ` ``` `.
