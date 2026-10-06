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

## A file pasted twice

Decide what a paste does when the document already holds the same file.
A second paste of the figure of an open cover could reuse the image, warn,
or make a copy.

- The digest is the SHA-256 of the bytes, so it matches across uploads.
  The object and the key do not.
- The editor hashes the file before `client.bytes`, which already keeps
  the blob for upload. Radif does not export its hashing.
- The images under the document come from one read through the binding.
  The comparison runs in memory, since a radif query cannot match a part
  of a `Bytes` value.
- `paste` answers the atom at once, before the hash. On a match, the row
  is not written, and the atom has to move to the existing image. The
  view has no way yet to change an atom's text from outside.
- Two atoms on one image share its title, description and rotation.
  Removing one atom must not remove the image.
