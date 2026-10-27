import { blocked } from "./content.mjs"

const textMutations = new Set([
  "addComment", "updateIssueComment", "createIssue", "updateIssue", "createPullRequest", "updatePullRequest",
  "createDiscussion", "updateDiscussion", "addDiscussionComment", "updateDiscussionComment",
  "addPullRequestReview", "submitPullRequestReview", "updatePullRequestReview", "dismissPullRequestReview",
  "addPullRequestReviewComment", "updatePullRequestReviewComment", "addPullRequestReviewThread",
  "addPullRequestReviewThreadReply", "createProjectV2", "updateProjectV2", "addProjectV2DraftIssue",
  "updateProjectV2DraftIssue",
])

const metadataMutations = new Set([
  "closeIssue", "reopenIssue", "closePullRequest", "reopenPullRequest", "mergePullRequest",
  "markPullRequestReadyForReview", "convertPullRequestToDraft", "addLabelsToLabelable", "removeLabelsFromLabelable",
  "addAssigneesToAssignable", "removeAssigneesFromAssignable", "requestReviews", "deleteIssueComment",
  "deleteDiscussionComment", "deletePullRequestReview", "deletePullRequestReviewComment",
  "resolveReviewThread", "unresolveReviewThread", "addReaction", "removeReaction", "lockLockable", "unlockLockable",
])
const optionalBodyMutations = new Set(["createIssue", "createPullRequest", "addPullRequestReview", "submitPullRequestReview"])

function tokenize(source) {
  const tokens = []
  const expression = /\s+|#[^\r\n]*|,|\uFEFF|\.\.\.|"""(?:\\"""|[\s\S])*?"""|"(?:\\.|[^"\\\r\n])*"|[_A-Za-z][_0-9A-Za-z]*|-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?|[!$():=@\[\]{}|&]/gy
  let offset = 0
  while (offset < source.length) {
    expression.lastIndex = offset
    const match = expression.exec(source)
    if (!match) blocked("Cannot safely parse this GraphQL document; use explicit GraphQL variables or a REST body.")
    offset = expression.lastIndex
    if (/^(?:\s|#|,|\uFEFF)/.test(match[0])) continue
    tokens.push({ raw: match[0], start: match.index, end: offset })
  }
  return tokens
}

function decodeString(raw) {
  if (!raw.startsWith('"""')) return JSON.parse(raw)
  const lines = raw.slice(3, -3).replaceAll('\\"""', '"""').replace(/\r\n?/g, "\n").split("\n")
  const indentation = Math.min(...lines.slice(1).filter((line) => /\S/.test(line)).map((line) => line.match(/^[ \t]*/)[0].length))
  for (let index = 1; index < lines.length; index++) lines[index] = lines[index].slice(Number.isFinite(indentation) ? indentation : 0)
  while (lines.length && !/\S/.test(lines[0])) lines.shift()
  while (lines.length && !/\S/.test(lines.at(-1))) lines.pop()
  return lines.join("\n")
}

function parse(source) {
  const tokens = tokenize(source)
  let index = 0
  const peek = () => tokens[index]?.raw
  const take = (expected) => {
    const token = tokens[index++]
    if (!token || (expected && token.raw !== expected)) blocked("Cannot safely parse the GraphQL mutation.")
    return token
  }
  const value = () => {
    const token = take()
    if (token.raw === "$") return { kind: "variable", name: take().raw }
    if (token.raw === "{") {
      const fields = []
      while (peek() !== "}") {
        const key = take().raw
        take(":")
        fields.push({ key, value: value() })
      }
      take("}")
      return { kind: "object", token, fields }
    }
    if (token.raw === "[") {
      const items = []
      while (peek() !== "]") items.push(value())
      take("]")
      return { kind: "list", items }
    }
    return { kind: token.raw.startsWith('"') ? "string" : "scalar", token }
  }
  const argumentsList = () => {
    const fields = []
    if (peek() !== "(") return fields
    take("(")
    while (peek() !== ")") {
      const key = take().raw
      take(":")
      fields.push({ key, value: value() })
    }
    take(")")
    return fields
  }
  const directives = () => {
    while (peek() === "@") {
      take("@")
      take()
      argumentsList()
    }
  }
  const selection = () => {
    take("{")
    const fields = []
    while (peek() !== "}") {
      if (peek() === "...") {
        take()
        if (peek() === "on") { take(); take() }
        else if (peek() !== "@" && peek() !== "{") take()
        directives()
        if (peek() === "{") selection()
        fields.push({ spread: true })
        continue
      }
      let name = take().raw
      if (peek() === ":") {
        take(":")
        name = take().raw
      }
      const args = argumentsList()
      directives()
      const children = peek() === "{" ? selection() : []
      fields.push({ name, args, children })
    }
    take("}")
    return fields
  }
  const operations = []
  while (index < tokens.length) {
    if (peek() === "fragment") {
      take(); take(); take("on"); take()
      directives()
      selection()
      continue
    }
    const kind = peek() === "{" ? "query" : take().raw
    if (!["query", "mutation", "subscription"].includes(kind)) blocked("Unsupported GraphQL operation.")
    const name = !["(", "{", "@"].includes(peek()) ? take().raw : undefined
    const defaults = Object.create(null)
    if (peek() === "(") {
      take("(")
      while (peek() !== ")") {
        take("$")
        const variable = take().raw
        take(":")
        while (peek() && !["=", "$", ")", "@"].includes(peek())) take()
        if (peek() === "=") { take("="); defaults[variable] = value() }
        directives()
      }
      take(")")
    }
    directives()
    operations.push({ kind, name, defaults, fields: selection() })
  }
  return operations
}

const textKeys = new Set(["body", "bodyText", "readme", "message"])
const nonMarkdownKeys = new Set(["shortDescription", "description", "commitHeadline", "commitBody"])

export function rewriteGraphQL(source, variables, operationName, annotate) {
  const operations = parse(source)
  const operation = operationName ? operations.find((item) => item.name === operationName) : operations.length === 1 ? operations[0] : undefined
  if (!operation) blocked("Select exactly one GraphQL operation with operationName.")
  if (operation.kind !== "mutation") return { source, variables, changed: false }
  const replacements = []
  const changedVariables = new Set()
  const usedVariables = new Map()
  let changed = false

  const materialize = (node) => {
    if (!node) return undefined
    if (node.kind === "string") return decodeString(node.token.raw)
    if (node.kind === "object") return Object.fromEntries(node.fields.map(({ key, value }) => [key, materialize(value)]))
    if (node.kind === "list") return node.items.map(materialize)
    if (node.kind === "variable") return variables[node.name]
    try { return JSON.parse(node.token.raw) } catch { return node.token.raw }
  }
  const walkJSON = (item, text = false) => {
    if (text) { changed = true; return annotate(item) }
    if (Array.isArray(item)) return item.map((value) => walkJSON(value))
    if (item && typeof item === "object") return Object.fromEntries(Object.entries(item).map(([key, value]) => {
      if (nonMarkdownKeys.has(key)) blocked(`GraphQL field ${key} is not a supported Markdown publishing body.`)
      return [key, walkJSON(value, textKeys.has(key))]
    }))
    return item
  }
  const walk = (node, text = false, addBody = false) => {
    if (node.kind === "variable") {
      if (changedVariables.has(node.name)) return
      let current = variables[node.name] ?? materialize(operation.defaults[node.name])
      if (addBody && current && typeof current === "object" && !Object.hasOwn(current, "body")) current = { ...current, body: "" }
      const before = changed
      changed = false
      const rewritten = walkJSON(current, text)
      const modified = changed
      changed = before || modified
      if (modified) { variables[node.name] = rewritten; changedVariables.add(node.name) }
    } else if (text) {
      if (node.kind !== "string") blocked("A GraphQL publishing body must be a string.")
      replacements.push({ ...node.token, value: JSON.stringify(annotate(decodeString(node.token.raw))) })
      changed = true
    } else if (node.kind === "object") {
      for (const field of node.fields) {
        if (nonMarkdownKeys.has(field.key)) blocked(`GraphQL field ${field.key} is not a supported Markdown publishing body.`)
        walk(field.value, textKeys.has(field.key))
      }
      if (addBody && !node.fields.some((field) => field.key === "body")) {
        replacements.push({ start: node.token.end, end: node.token.end, value: `body: ${JSON.stringify(annotate(""))}, ` })
        changed = true
      }
    } else if (node.kind === "list") {
      node.items.forEach((item) => walk(item))
    }
  }
  const count = (node) => {
    if (node.kind === "variable") usedVariables.set(node.name, (usedVariables.get(node.name) ?? 0) + 1)
    if (node.kind === "object") node.fields.forEach((field) => count(field.value))
    if (node.kind === "list") node.items.forEach(count)
  }
  const countFields = (fields) => fields.forEach((field) => {
    field.args?.forEach((argument) => count(argument.value))
    if (field.children) countFields(field.children)
  })
  countFields(operation.fields)
  for (const field of operation.fields) {
    if (field.spread) blocked("Expand mutation-root GraphQL fragments before posting.")
    if (!textMutations.has(field.name) && !metadataMutations.has(field.name)) blocked(`Unsupported GraphQL mutation ${field.name}.`)
    for (const argument of field.args) {
      if (argument.key === "input") walk(argument.value, false, optionalBodyMutations.has(field.name))
    }
  }
  for (const variable of changedVariables) {
    if (usedVariables.get(variable) !== 1) blocked(`GraphQL variable $${variable} is shared; use a separate variable for the publishing body.`)
  }
  for (const replacement of replacements.sort((left, right) => right.start - left.start)) {
    source = source.slice(0, replacement.start) + replacement.value + source.slice(replacement.end)
  }
  return { source, variables, changed }
}
