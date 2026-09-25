// What crosses the storage port. A section is the unit a host stores and
// shares: one id and a keyed array of blocks, each block its id and its text
// in canonical markdown. The host never sees a mark.

type block = (Doc.id, string)

type t = {id: Doc.id, blocks: array<block>}

// The port, as plain data. `sections` is what the host has given the editor
// to edit, by id. `update` receives the sections an edit changed, whole,
// once per act. The core observes nothing and writes nothing back into
// `sections`: a rendering binding decides when to re-read it, and a host
// decides what to do with an update.
type storage = {sections: Dict.t<t>, update: array<t> => unit}
