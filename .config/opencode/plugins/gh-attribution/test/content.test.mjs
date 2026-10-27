import assert from "node:assert/strict"
import { test } from "node:test"
import { modelAttribution, parseArgs, prepend } from "../content.mjs"

const attribution = { model: "gpt-6.1-sol", effort: "high" }
const header = "<sup>[Posted by gpt-6.1-sol @ high via opencode]</sup>"

test("prepends a superscript header and preserves the body verbatim", () => {
  const body = "# Heading\n\n`code` & emoji 🦊\n"
  assert.equal(prepend(body, attribution), `${header}\n\n${body}`)
  assert.equal(prepend("", attribution), header)
})

test("retries and edits do not accumulate attribution headers", () => {
  assert.equal(prepend(prepend("body", attribution), attribution), `${header}\n\nbody`)
  assert.equal(prepend("<sup>[Posted by old-model @ low]</sup>\r\n\r\nbody", attribution), `${header}\n\nbody`)
  assert.equal(prepend("<sup>[Posted by old-model @ low via opencode]</sup>\r\n\r\nbody", attribution), `${header}\n\nbody`)
  assert.equal(prepend("Quoted:\n<sup>[Posted by old @ low]</sup>", attribution), `${header}\n\nQuoted:\n<sup>[Posted by old @ low]</sup>`)
})

test("header-only bodies have no trailing paragraph break across retries", () => {
  assert.equal(prepend(prepend("", attribution), attribution), header)
  assert.equal(prepend("<sup>[Posted by old-model @ low]</sup>", attribution), header)
  assert.equal(prepend(`${header}\n\n`, attribution), header)
})

test("escapes session metadata and blocks unknown attribution", () => {
  assert.match(prepend("body", { model: "a<b&c", effort: '"high"' }), /a&lt;b&amp;c @ &quot;high&quot;/)
  assert.throws(() => prepend("body", undefined), /could not be resolved/)
  assert.throws(() => prepend(null, attribution), /must be a string/)
})

test("resolves selected variants, configured defaults, and request overrides", () => {
  const reference = { providerID: "openai", id: "test", variant: "deep" }
  const catalog = [{ providerID: "openai", id: "test", settings: { reasoningEffort: "low" }, variants: [{ id: "deep", settings: { reasoningEffort: "high" } }] }]
  assert.deepEqual(modelAttribution(reference, catalog), { model: "test", effort: "high" })
  assert.equal(modelAttribution(reference, catalog, { reasoningEffort: "medium" }).effort, "medium")
  assert.equal(modelAttribution({ ...reference, variant: undefined }, catalog).effort, "low")
  assert.equal(modelAttribution(reference).effort, "deep")
  assert.equal(modelAttribution({ ...reference, variant: undefined }).effort, "default")
  assert.equal(modelAttribution(undefined), undefined)
})

test("argv parsing does not confuse literal bodies with options", () => {
  const parsed = parseArgs(["--body", "--help", "-bmore", "--body=last", "--help=false"], {
    "--body": "value", "-b": "value", "--help": "boolean",
  })
  assert.deepEqual(parsed.flags.map(({ value }) => value), ["--help", "more", "last", "false"])
})
