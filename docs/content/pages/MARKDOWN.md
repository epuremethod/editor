# Markdown

A writer edits a page of this site in the browser, while minidoc serves the
site in dev mode. The page's markdown file becomes a document. The editor
edits its sections. The dev server writes the file back, and the file stays
the source. This page says how a file becomes sections and atoms, how the
sections become a file again, and how the file is written. It is a proposal.
The section "Cost" says what each part asks of the code.

```flow One edit, from the file to the file
read | the file becomes frontmatter, sections, blocks and atoms
edit | the editor applies acts to one section
write | the changed sections become markdown, atoms included
post | the browser sends the whole file to the dev server
save | the dev server writes the file, and minidoc rebuilds the site
```

The browser does the whole conversion. The dev server receives text that is
already markdown, and writes it. It reads no block and no atom.

## Reading a file

A file is a frontmatter and a body. The frontmatter is the YAML between the
two `---` lines at the top. The editor keeps it as text and writes it back
as it was. Editing it is for later.

The body splits into sections at each heading of level two. A section
starts with its heading, which is its first block. The text before the
first such heading is a section of its own. So a section of the file is a
section of the model, and it matches one entry in the page's contents.

Each piece of markdown becomes a block, an atom, or both.

| Markdown | In the model |
| --- | --- |
| a paragraph, over several lines | a paragraph, its lines joined by a space |
| `#`, `##` or `###` and a title | a heading at that level |
| `- ` and its text, over several lines | an item |
| `$…$` inside a line | an atom of type math, and its reference in the block |
| `$$…$$` alone | an atom of type math, in a display |
| a `schema` or `flow` fence | an atom of that type, in a display |
| a minidoc var between double braces | an atom of type minidoc, in a display |
| any other fence, a table, HTML, a quote, a numbered or nested list | an atom of type markdown, in a display |

The last row keeps the editor honest. What the model cannot express as blocks
is kept whole, as the source of an atom. The markdown type draws that
source as the site would render it, and the box under the atom edits it as
text. Nothing in a file is lost or rewritten because the editor does not
know it.

Minidoc reads the file as a template before markdown reads it. A minidoc
escape, the name between backticks inside double braces, becomes the plain
text it stands for. A minidoc var becomes an atom, since its value comes
from the build and not from the file.

An atom's id is minted when the file is read. It never goes into the file,
as the Files section of the model page says. An id lives as long as the
page stays open.

## Writing a file

A block that no act touched writes the source it was read from, byte for
byte. So an edit changes the lines of the blocks it touched, and a diff of
the file shows only them.

A block that an act touched is written in canonical markdown, the way the
port writes it. It is then wrapped at 76 columns, the width of these pages.
A wrap never falls inside a code span, a link, or an atom.

Each atom is written back in its own form: math between single dollars in
a line and between double dollars alone, a schema or a flow as a fence, a
minidoc var between double braces, and markdown as its source. Plain text
that contains double braces is written with the minidoc escape, so the build
does not read it as a var.

Blocks are parted by one blank line. Items of one list are not. The
frontmatter comes first, as it was read.

Reading a file and writing it back with no act gives the same bytes. That
is the first scenario, run on every page of this site.

## Saving in dev mode

The dev build adds one script to the page and names the page's file on the
article. The published site gets neither.

The script asks the dev server for the file's text, reads it into sections,
and draws the editor in place of the rendered article. It fetches the file
rather than reading the page. The page is already rendered, and its
templates are already filled.

The storage binding keeps the whole file. On `update`, it puts the changed
sections in their places, writes the file, and posts it. It posts a short
time after the last act, and at once when the page loses focus. The post
carries the file's path, its text, and a digest of the text it replaced.

The dev server writes the file only under the site's content folder, only a
markdown file, and only when the file on disk still has the digest the post
names. Otherwise it answers with a conflict and the text on disk.

A write changes a watched file, so minidoc rebuilds the site and tells every
open tab to reload. The tab that wrote must not reload, or the writer loses
the caret. Minidoc's reload message should name the files that changed. A
tab that edits a file skips a reload when that file is the only change and
its text matches the file on disk. It reloads for any other change, such as an
edited fixture.

## What minidoc needs

Minidoc's dev server serves files and one reload stream. It answers no post.
It needs two small, general additions.

- A request handler that a site passes to `dev`. The editor's site uses it
  to answer the read and the post. Minidoc stays free of the editor.
- A reload message that names the changed files.

## Cost

| Part | Where | Difficulty |
| --- | --- | --- |
| The block reader: frontmatter, sections, forms, fences, the source of each block | `@epure/editor` | medium |
| The writer: verbatim for an untouched block, canonical and wrapped for a touched one | `@epure/editor` | medium |
| Inline math, and the minidoc escape, in the inline reader and writer | `@epure/editor` | low |
| The round trip on every page of this site | `@epure/editor` | low, once the reader exists |
| One view per section, stacked, on the site's styles | `@tilia/editor` | medium |
| The schema, flow, minidoc and markdown types | the site | low |
| The dev script, the storage binding and the post | the site | low |
| The request handler and the named reload | minidoc | low |

The reader and the writer are the heart of the work, and the risk is in
the reader. It must keep the exact source of every block, so it is written
in the core with no markdown library. The core depends on nothing, and a
library would hide where a block starts and ends. Its grammar is small,
since everything it does not know becomes a markdown atom.

The view is the second risk. It draws one section today, and a page contains
several. Each section gets its own view, one under the other, and a caret
does not cross from one to the next.

## Not yet

- Editing the frontmatter.
- Tables, quotes, numbered and nested lists as blocks the editor edits.
- A merge with a file that changed on disk while the page was open. The
  port's `merge` can take it, with the text on disk as the row that landed.
- Ids kept across reloads, by matching a diff to the previous read.
- Editing on the published site.

## Open

Wrapping at 76 columns or writing one line per paragraph. The pages of this
site wrap, so a touched paragraph wraps too.

A section per heading of level two, or one section per page. The contents
of a page list its headings of level two, so the proposal splits there.
