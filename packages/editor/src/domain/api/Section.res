// What crosses the storage port. A section is the unit a host stores and
// shares: one id, a keyed array of blocks, each block its id and its text
// in canonical markdown, and the entries the blocks refer to, each its id
// and its text, sorted by id. An entry's type rides on the first line of
// its text and its source follows, the way a block's form rides on its
// line's prefix. The host never sees a mark and never reads a type.

type block = (Doc.id, string)

type entry = (Doc.id, string)

type t = {id: Doc.id, blocks: array<block>, entries: array<entry>}

// The port, as plain data. `sections` is what the host has given the editor
// to edit, in the order they read. `update` receives the sections an edit changed, whole,
// once per act. The core observes nothing and writes nothing back into
// `sections`: a rendering binding decides when to re-read it, and a host
// decides what to do with an update.
type storage = {sections: array<t>, update: array<t> => unit}
