// What crosses the storage port. A section is the unit a host stores and
// shares: one id, a keyed array of blocks, each block its id and its text
// in canonical markdown, and the atoms the blocks refer to, each its id
// and its text, sorted by id. An atom's type rides on the first line of
// its text and its source follows, the way a block's form rides on its
// line's prefix. The host never sees a mark and never reads a type.

type block = (Doc.id, string)

type atom = (Doc.id, string)

type t = {id: Doc.id, blocks: array<block>, atoms: array<atom>}

// The port, as plain data. `sections` is what the host has given the editor
// to edit, in the order they read. `update` receives the sections a save
// changed, whole. `merge` is the host's three-way merge of a section: the
// row the editor last took, that row with the typed text over it, and the
// row that landed. The core observes nothing, merges nothing and writes
// nothing back into `sections`: a rendering binding decides when to re-read
// it, and a host decides what to do with an update.
type storage = {
  sections: array<t>,
  update: array<t> => unit,
  merge: (~base: t, ~local: t, ~remote: t) => t,
}
