import MarkdownIt from "markdown-it"
import anchor from "markdown-it-anchor"
import {flow, schema} from "./schema.mjs"

export function slugify(value) {
  return value
    .toLowerCase()
    .trim()
    .replace(/<[^>]+>/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
}

const md = new MarkdownIt({html: true, linkify: true, typographer: true})

md.use(anchor, {
  level: [2, 3],
  slugify,
  permalink: anchor.permalink.linkInsideHeader({
    symbol: "■",
    placement: "after",
    ariaHidden: true,
    class: "heading-anchor",
  }),
})

// A `schema` fence is a structure and a `flow` fence a chain of steps: each
// is drawn rather than painted.
const drawn = {schema, flow}

const fence = md.renderer.rules.fence
md.renderer.rules.fence = (tokens, index, options, env, self) => {
  const info = tokens[index].info.trim()
  const name = info.split(" ")[0]
  const draw = drawn[name]
  if (draw) return draw(tokens[index].content, info.slice(name.length).trim())
  return fence(tokens, index, options, env, self)
}

md.renderer.rules.table_open = () => '<div class="table-wrap"><table>\n'
md.renderer.rules.table_close = () => "</table></div>\n"

export function docsMd(text) {
  return md.render(text)
}

function plain(html) {
  return html
    .replace(/<a class="heading-anchor"[^>]*>.*?<\/a>/g, "")
    .replace(/<[^>]+>/g, "")
    .trim()
}

// The contents of a page, read off its rendered sections: one entry per `h2`.
export function docsToc(text) {
  const entries = [...md.render(text).matchAll(/<h2 id="([^"]+)"[^>]*>(.*?)<\/h2>/g)].map(
    ([, id, title]) => `<li><a href="#${id}">${plain(title)}</a></li>`,
  )
  return entries.length ? `<ol class="contents__sections">${entries.join("")}</ol>` : ""
}
