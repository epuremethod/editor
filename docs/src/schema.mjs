// The `schema` fence: a structure, drawn. The body is an outline. A line
// that starts with a capitalized word is a row of that class, and every row
// indented under another hangs under it. A line that starts with a lowercase
// id is a block, one entry of the section's keyed array, drawn the way the
// Operations page draws a block. A block whose text starts with `~` is an
// embed, and the rest of its line names the row it draws. Trailing `[...]`
// groups are badges.
//
// The `flow` fence: a chain of steps, one per line, `name | note`.

function escape(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
}

const rowLine = /^([A-Z][A-Za-z]*)(?:\s+(.*))?$/
const blockLine = /^([a-z][a-z0-9]*)(?:\s+(.*))?$/
const badge = /\s*\[([^\]]+)\]\s*$/

function badges(text) {
  const found = []
  let rest = text ?? ""
  let match
  while ((match = badge.exec(rest))) {
    found.unshift(match[1])
    rest = rest.slice(0, match.index)
  }
  return {text: rest.trim(), badges: found}
}

function outline(body) {
  const lines = body.split("\n").filter(line => line.trim() !== "")
  const root = {children: []}
  const stack = [{depth: -1, node: root}]
  for (const line of lines) {
    const depth = line.match(/^ */)[0].length / 2
    const node = {source: line.trim(), children: []}
    while (stack[stack.length - 1].depth >= depth) stack.pop()
    stack[stack.length - 1].node.children.push(node)
    stack.push({depth, node})
  }
  return root.children
}

function chips(list) {
  return list.map(text => `<span class="schema__badge">${escape(text)}</span>`).join("")
}

function block(id, source) {
  const {text, badges: tags} = badges(source)
  let shown
  if (text === "") {
    shown = '<span class="tree__empty">—</span>'
  } else if (text.startsWith("~")) {
    shown = `<span class="schema__embed">${escape(text.slice(1).trim())}</span>`
  } else if (text.startsWith("$$")) {
    shown = `<code class="schema__formula">${escape(text)}</code>`
  } else if (text.startsWith("#")) {
    shown = `<strong>${escape(text.replace(/^#+\s*/, ""))}</strong>`
  } else {
    shown = escape(text)
  }
  return `<li class="tree__block"><span class="tree__id">${escape(id)}</span><span class="tree__text">${shown}${chips(tags)}</span></li>`
}

function row(kind, source, children, nested) {
  const {text, badges: tags} = badges(source)
  if (nested) tags.unshift("under")
  const head = `<p class="schema__head"><span class="schema__class">${escape(kind)}</span><span class="schema__label">${escape(text)}</span><span class="schema__badges">${chips(tags)}</span></p>`
  const body = children.length ? `<div class="schema__body">${draw(children, true)}</div>` : ""
  return `<div class="schema__row">${head}${body}</div>`
}

// Blocks that follow each other share one tree, so they read as one keyed
// array. A row between them starts a new one.
function draw(nodes, nested) {
  const parts = []
  let tree = []
  const flush = () => {
    if (tree.length) parts.push(`<ol class="tree schema__tree">${tree.join("")}</ol>`)
    tree = []
  }
  for (const node of nodes) {
    const asRow = rowLine.exec(node.source)
    if (asRow) {
      flush()
      parts.push(row(asRow[1], asRow[2] ?? "", node.children, nested))
      continue
    }
    const asBlock = blockLine.exec(node.source)
    if (!asBlock) throw new Error(`A schema line is a Row or a block id: ${node.source}`)
    if (node.children.length) throw new Error(`A block holds nothing under it: ${node.source}`)
    tree.push(block(asBlock[1], asBlock[2] ?? ""))
  }
  flush()
  return parts.join("")
}

export function schema(body, caption) {
  const inner = draw(outline(body), false)
  const under = caption ? `<figcaption class="schema__caption">${escape(caption)}</figcaption>` : ""
  return `<figure class="schema">${inner}${under}</figure>`
}

export function flow(body, caption) {
  const steps = body
    .split("\n")
    .filter(line => line.trim() !== "")
    .map(line => {
      const [name, ...note] = line.split("|")
      return `<li class="flow__step"><span class="flow__name">${escape(name.trim())}</span><span class="flow__note">${escape(note.join("|").trim())}</span></li>`
    })
  const under = caption ? `<figcaption class="schema__caption">${escape(caption)}</figcaption>` : ""
  return `<figure class="flow"><ol class="flow__steps">${steps.join("")}</ol>${under}</figure>`
}
