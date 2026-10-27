import assert from "node:assert/strict"
import { mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync, existsSync } from "node:fs"
import { dirname, join } from "node:path"
import { tmpdir } from "node:os"
import { spawnSync } from "node:child_process"
import { fileURLToPath } from "node:url"
import { after, test } from "node:test"

const directory = dirname(dirname(fileURLToPath(import.meta.url)))
const base = join(tmpdir(), "opencode")
mkdirSync(base, { recursive: true })
const temporary = mkdtempSync(join(base, "gh-attribution-test-"))
const realGH = join(temporary, "fake-gh")
const body = "A quoted 'body' with $variables, `code`,\n\nand emoji 🦊\n"
const header = "<sup>[Posted by gpt-6.1-sol @ high via opencode]</sup>"
writeFileSync(realGH, `#!/usr/bin/env node
const fs = require('node:fs');
const args = process.argv.slice(2);
const files = {};
for (let i = 0; i < args.length; i++) {
  if (['--body-file', '--notes-file', '--input'].includes(args[i])) {
    const path = args[i + 1];
    files[path] = fs.readFileSync(path === '-' ? 0 : path, 'utf8');
  }
}
console.log(JSON.stringify({ args, files, attribution: process.env.OPENCODE_GH_ATTRIBUTION }));
process.exitCode = Number(process.env.FAKE_GH_EXIT || 0);
`, { mode: 0o700 })
after(() => rmSync(temporary, { recursive: true, force: true }))

function invoke(args, input = "", additional = {}) {
  const result = spawnSync(process.execPath, [join(directory, "wrapper.mjs"), ...args], {
    encoding: "utf8", input,
    env: { ...process.env, OPENCODE_GH_REAL: realGH, OPENCODE_GH_ATTRIBUTION: JSON.stringify({ model: "gpt-6.1-sol", effort: "high" }), OPENCODE_GH_TMPDIR: temporary, ...additional },
  })
  return { ...result, posted: result.stdout ? JSON.parse(result.stdout) : undefined }
}

function value(result, flag) { return result.posted.args[result.posted.args.indexOf(flag) + 1] }

for (const [namespace, verb] of [["issue", "create"], ["issue", "edit"], ["issue", "comment"], ["pr", "create"], ["pr", "edit"], ["pr", "comment"], ["pr", "review"], ["discussion", "create"]]) {
  test(`annotates ${namespace} ${verb} bodies`, () => {
    const result = invoke([namespace, verb, "--body", body])
    assert.equal(result.status, 0, result.stderr)
    assert.equal(value(result, "--body"), `${header}\n\n${body}`)
  })
}

test("handles equals/attached body flags, leading repository flags, and flag-looking values", () => {
  for (const args of [["pr", "comment", `--body=${body}`], ["pr", "comment", `-b${body}`], ["-R", "owner/repo", "pr", "comment", "-b", body], ["--repo=owner/repo", "pr", "comment", "-b", body]]) {
    const result = invoke(args)
    assert.equal(result.status, 0, result.stderr)
    assert.equal(value(result, "--body"), `${header}\n\n${body}`)
  }
  assert.equal(value(invoke(["issue", "create", "--title", "--help", "--body", "--body-file"]), "--body"), `${header}\n\n--body-file`)
})

test("body files and stdin are copied, never modified, and temporary files are removed", () => {
  const original = join(temporary, "body.md")
  writeFileSync(original, body)
  for (const source of [original, "-"]) {
    const result = invoke(["pr", "comment", "--body-file", source], body)
    assert.equal(result.status, 0, result.stderr)
    const path = value(result, "--body-file")
    assert.equal(result.posted.files[path], `${header}\n\n${body}`)
    assert.equal(existsSync(path), false)
  }
  assert.equal(readFileSync(original, "utf8"), body)
  assert.equal(readdirSync(temporary).some((entry) => entry.startsWith("gh-")), false)
})

test("annotates release notes, close comments, and bodyless approvals", () => {
  assert.equal(value(invoke(["release", "create", "v1", "--notes", body, "--generate-notes"]), "--notes"), `${header}\n\n${body}`)
  assert.equal(value(invoke(["issue", "close", "1", "--comment", body]), "--comment"), `${header}\n\n${body}`)
  assert.equal(value(invoke(["pr", "review", "1", "--approve"]), "--body"), header)
  assert.equal(value(invoke(["release", "create", "v1", "-p", "-n", body]), "--notes"), `${header}\n\n${body}`)
})

test("refuses ambiguous writes before invoking gh with actionable retry guidance", () => {
  for (const args of [
    ["pr", "create", "--fill"], ["issue", "create", "--editor"], ["pr", "comment", "--web"],
    ["my-extension", "post"], ["my-extension", "list"], ["extension", "exec", "my-extension"],
    ["api", "unknown/publishing/endpoint", "-f", "body=hi"],
    ["pr", "comment", "--body", "one", "--body-file", "two"],
  ]) {
    const result = invoke(args)
    assert.equal(result.status, 1, args.join(" "))
    assert.equal(result.posted, undefined)
    assert.match(result.stderr, /Nothing was posted\. Retry automatically/)
  }
})

test("does not require attribution for reads or metadata-only edits", () => {
  for (const args of [["pr", "view", "1"], ["api", "repos/o/r/issues"], ["api", "search/issues", "-X", "GET", "-f", "q=test"], ["issue", "edit", "1", "--title", "new title"]]) {
    const result = invoke(args, "", { OPENCODE_GH_ATTRIBUTION: "" })
    assert.equal(result.status, 0, result.stderr)
    assert.deepEqual(result.posted.args, args)
  }
  const result = invoke(["pr", "comment", "--body", body], "", { OPENCODE_GH_ATTRIBUTION: "" })
  assert.equal(result.status, 1)
  assert.match(result.stderr, /could not be resolved/)
})

test("annotates REST fields, typed files/stdin, nested review comments, and dismissal messages", () => {
  const original = join(temporary, "field.md")
  writeFileSync(original, body)
  for (const args of [
    ["api", "repos/o/r/issues/1/comments", "-f", `body=${body}`],
    ["api", "repos/o/r/issues/1/comments", "-F", `body=@${original}`],
    ["api", "repos/o/r/issues/1/comments", "-F", "body=@-"],
    ["api", "repos/o/r/pulls/1/reviews", "-f", `comments[][body]=${body}`],
    ["api", "repos/o/r/pulls/1/reviews/2/dismissals", "-X", "PUT", "-f", `message=${body}`],
  ]) {
    const result = invoke(args, body)
    assert.equal(result.status, 0, result.stderr)
    assert.ok(result.posted.args.some((argument) => argument.endsWith(`${header}\n\n${body}`)))
  }
})

test("annotates every review body in JSON input without touching other fields", () => {
  const payload = { body, event: "COMMENT", comments: [{ path: "a.ts", line: 1, body }, { path: "b.ts", line: 2, body: "second" }] }
  const result = invoke(["api", "repos/o/r/pulls/1/reviews", "--input", "-"], JSON.stringify(payload))
  assert.equal(result.status, 0, result.stderr)
  const rewritten = JSON.parse(result.posted.files[value(result, "--input")])
  assert.deepEqual(rewritten, { ...payload, body: `${header}\n\n${body}`, comments: payload.comments.map((comment) => ({ ...comment, body: `${header}\n\n${comment.body}` })) })
})

test("adds attribution to optional empty REST descriptions and rejects malformed input", () => {
  const result = invoke(["api", "repos/o/r/issues", "-f", "title=Title"])
  assert.ok(result.posted.args.includes(`body=${header}`))
  assert.equal(invoke(["api", "repos/o/r/issues", "--input", "-"], "not JSON").status, 1)
})

test("GraphQL body variables can have arbitrary names; unrelated typed fields survive", () => {
  const query = "mutation($target:ID!,$text:String!,$owner:String!){addComment(input:{subjectId:$target,body:$text}){commentEdge{node{id}}}}"
  const result = invoke(["api", "graphql", "-f", `query=${query}`, "-f", "target=ID", "-f", `text=${body}`, "-F", "owner={owner}"])
  assert.equal(result.status, 0, result.stderr)
  assert.ok(result.posted.args.includes(`text=${header}\n\n${body}`))
  assert.ok(result.posted.args.includes("owner={owner}"))
  assert.ok(result.posted.args.includes("-F"))
  const typed = invoke(["api", "graphql", "-f", `query=${query}`, "-f", "target=ID", "-F", "text={owner}", "-F", "owner={owner}"])
  assert.ok(typed.posted.args.includes(`text=${header}\n\n{owner}`))
  assert.ok(typed.posted.args.includes("--field"))
})

test("GraphQL literal and block-string bodies are parsed, not matched with a body regex", () => {
  for (const literal of [JSON.stringify(body), '"""\n  A block\n  with indentation\n"""']) {
    const query = `mutation { a:addComment(input:{subjectId:"ID",body:${literal}}){commentEdge{node{body: id}}} }`
    const result = invoke(["api", "graphql", "-f", `query=${query}`])
    assert.equal(result.status, 0, result.stderr)
    const rewritten = value(result, "--raw-field").slice("query=".length)
    assert.ok(rewritten.includes(JSON.stringify(`${header}\n\n${literal.startsWith('"""') ? "A block\nwith indentation" : body}`)))
    assert.ok(rewritten.includes("body: id"))
  }
})

test("GraphQL JSON input annotates nested objects, not titles or paths", () => {
  const payload = { query: "mutation($input:AddPullRequestReviewInput!){addPullRequestReview(input:$input){pullRequestReview{id}}}", variables: { input: { pullRequestId: "ID", body, threads: [{ body: "inline", path: "a.ts", line: 1 }] } } }
  const result = invoke(["api", "graphql", "--input", "-"], JSON.stringify(payload))
  assert.equal(result.status, 0, result.stderr)
  const rewritten = JSON.parse(result.posted.files[value(result, "--input")])
  assert.equal(rewritten.variables.input.body, `${header}\n\n${body}`)
  assert.deepEqual(rewritten.variables.input.threads, [{ body: `${header}\n\ninline`, path: "a.ts", line: 1 }])
})

test("bodyless GraphQL creations and approvals still disclose their author", () => {
  const query = 'mutation { createIssue(input:{repositoryId:"ID", title:"Title"}) { issue { id } } }'
  const literal = invoke(["api", "graphql", "-f", `query=${query}`])
  assert.equal(literal.status, 0, literal.stderr)
  assert.ok(value(literal, "--raw-field").includes(JSON.stringify(header)))
  const payload = { query: "mutation($input:AddPullRequestReviewInput!){addPullRequestReview(input:$input){clientMutationId}}", variables: { input: { pullRequestId: "ID", event: "APPROVE" } } }
  const variable = invoke(["api", "graphql", "--input", "-"], JSON.stringify(payload))
  assert.equal(variable.status, 0, variable.stderr)
  assert.equal(JSON.parse(variable.posted.files[value(variable, "--input")]).variables.input.body, header)
})

test("GraphQL text in non-Markdown fields and mutations over GET cannot slip through", () => {
  for (const args of [
    ["api", "graphql", "-f", 'query=mutation{mergePullRequest(input:{pullRequestId:"ID",commitBody:"text"}){clientMutationId}}'],
    ["api", "graphql", "-X", "GET", "-f", 'query=mutation{addComment(input:{subjectId:"ID",body:"text"}){clientMutationId}}'],
  ]) {
    const result = invoke(args)
    assert.equal(result.status, 1)
    assert.equal(result.posted, undefined)
  }
})

test("GraphQL queries replay inspected stdin unchanged", () => {
  const payload = JSON.stringify({ query: "query { viewer { ...F login } } fragment F on User { id }" })
  const args = ["api", "graphql", "--input", "-"]
  const result = invoke(args, payload, { OPENCODE_GH_ATTRIBUTION: "" })
  assert.equal(result.status, 0, result.stderr)
  assert.deepEqual(result.posted.args, args)
  assert.equal(result.posted.files["-"], payload)
})

test("GraphQL defaults and operationName work; shared variables and unknown mutations fail closed", () => {
  const query = 'mutation Post($text:String!="default body"){addComment(input:{subjectId:"ID",body:$text}){clientMutationId}} query Read{viewer{id}}'
  const result = invoke(["api", "graphql", "-f", `query=${query}`, "-f", "operationName=Post"])
  assert.equal(result.status, 0, result.stderr)
  assert.ok(result.posted.args.includes(`text=${header}\n\ndefault body`))
  for (const query of [
    'mutation($text:String!){createIssue(input:{repositoryId:"ID",title:$text,body:$text}){issue{id}}}',
    'mutation{unknownPublishingAction(input:{body:"text"}){id}}',
    'mutation{...Write} fragment Write on Mutation{addComment(input:{body:"text"}){id}}',
  ]) {
    const result = invoke(["api", "graphql", "-f", `query=${query}`, "-f", "text=shared"])
    assert.equal(result.status, 1)
    assert.equal(result.posted, undefined)
  }
})

test("wrapper propagates gh's exit status and resolves gh without recursion", () => {
  const result = invoke(["pr", "view", "1"], "", { FAKE_GH_EXIT: "7" })
  assert.equal(result.status, 7)
  const bin = join(temporary, "bin")
  mkdirSync(bin)
  writeFileSync(join(bin, "gh"), readFileSync(realGH), { mode: 0o700 })
  const unpinned = invoke(["pr", "view", "1"], "", { OPENCODE_GH_REAL: "", PATH: `${join(directory, "bin")}:${bin}:${process.env.PATH}` })
  assert.equal(unpinned.status, 0, unpinned.stderr)
})

test("shell pipelines and child scripts inherit attribution without rewriting shell syntax", () => {
  const result = spawnSync("/bin/zsh", ["-c", "printf '%s' 'pipeline body' | gh pr comment 1 --body-file -"], {
    encoding: "utf8",
    env: { ...process.env, PATH: `${join(directory, "bin")}:${process.env.PATH}`, OPENCODE_GH_REAL: realGH, OPENCODE_GH_ATTRIBUTION: JSON.stringify({ model: "gpt-6.1-sol", effort: "high" }), OPENCODE_GH_TMPDIR: temporary },
  })
  assert.equal(result.status, 0, result.stderr)
  const posted = JSON.parse(result.stdout)
  assert.equal(Object.values(posted.files)[0], `${header}\n\npipeline body`)
})
