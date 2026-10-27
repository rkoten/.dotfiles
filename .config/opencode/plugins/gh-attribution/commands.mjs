import { readFileSync } from "node:fs"
import { blocked, flagSpec, parseArgs, prepend, replaceArgs } from "./content.mjs"
import { rewriteGraphQL } from "./graphql.mjs"

const nativeSpec = flagSpec(
  `--body -b --body-file -F --notes -n --notes-file --comment -c --title -t --repo -R
   --assignee -a --add-assignee --remove-assignee --label -l --add-label --remove-label
   --project -p --add-project --remove-project --milestone -m --remove-reviewer --add-reviewer
   --reviewer -r --base -B --head -H --template -T --recover --category --category-id
   --discussion-category --target --notes-start-tag --reason --state --visibility`,
  `--help -h --editor -e --web -w --draft -d --fill -f --fill-first --fill-verbose
   --maintainer-edit --no-maintainer-edit --dry-run --edit-last --create-if-none --delete-last
   --yes --remove-milestone --delete-branch --lock-conversation --unlock-conversation --generate-notes
   --notes-from-tag --verify-tag --fail-on-no-commits --latest --prerelease`,
)

const apiSpec = flagSpec(
  "--method -X --field -F --raw-field -f --input --header -H --hostname --cache --preview -p --jq -q --template -t",
  "--help -h --include -i --paginate --silent --slurp --verbose --allow-escape-sequences",
)

function enabled(flag) { return flag && flag.value !== "false" }

function readBody(path, io) {
  return path === "-" ? io.stdin() : readFileSync(path, "utf8")
}

function native(args, namespace, verb, offset, attribution, io) {
  let spec = { ...nativeSpec }
  if (namespace === "pr" && verb === "review") {
    spec = { ...spec, ...flagSpec("", "--approve -a --comment -c --request-changes -r") }
  }
  if (namespace === "release") spec["-p"] = "boolean"
  const rest = args.slice(offset)
  const { flags } = parseArgs(rest, spec)
  const has = (names) => flags.some((flag) => names.includes(flag.name) && enabled(flag))
  if (has(["--help", "-h"])) return args
  if (has(["--editor", "-e", "--web", "-w", "--template", "-T", "--notes-from-tag"])) {
    blocked("Editor, browser, template, and tag-generated bodies cannot be inspected before publishing.")
  }
  const release = namespace === "release"
  const closing = ["close", "reopen"].includes(verb)
  const bodyNames = release ? ["--notes", "-n"] : closing ? ["--comment", "-c"] : ["--body", "-b"]
  const fileNames = release ? ["--notes-file", "-F"] : closing ? [] : ["--body-file", "-F"]
  const bodies = flags.filter((flag) => bodyNames.includes(flag.name) || fileNames.includes(flag.name))
  if (bodies.length > 1) blocked("Use one unambiguous body or body-file option.")
  if (!bodies.length) {
    if (namespace === "pr" && verb === "review" && has(["--approve", "-a"])) return [...args, "--body", prepend("", attribution)]
    if (["create", "comment", "review"].includes(verb) && !has(["--delete-last"])) {
      blocked("This posting command has no explicit body. Materialize any generated text before retrying.")
    }
    if (verb === "edit" && !flags.some((flag) => !["--repo", "-R"].includes(flag.name))) {
      blocked("Interactive edits cannot be inspected; provide the intended body explicitly.")
    }
    return args
  }
  const flag = bodies[0]
  const body = fileNames.includes(flag.name) ? readBody(flag.value, io) : flag.value
  const rewritten = prepend(body, attribution)
  const replacement = fileNames.includes(flag.name)
    ? [release ? "--notes-file" : "--body-file", io.temp(rewritten)]
    : [release ? "--notes" : closing ? "--comment" : "--body", rewritten]
  return [...args.slice(0, offset), ...replaceArgs(rest, [{ ...flag, args: replacement }])]
}

function restPolicy(endpoint) {
  const repo = "repos/[^/]+/[^/]+/"
  const patterns = [
    ["issues(?:/\\d+)?", "body"], ["issues/\\d+/comments", "body"], ["issues/comments/\\d+", "body"],
    ["pulls(?:/\\d+)?", "body"], ["pulls/\\d+/comments", "body"], ["pulls/comments/\\d+", "body"],
    ["pulls/\\d+/comments/\\d+/replies", "body"], ["pulls/\\d+/reviews(?:/\\d+)?", "body"],
    ["pulls/\\d+/reviews/\\d+/events", "body"], ["pulls/\\d+/reviews/\\d+/dismissals", "message"],
    ["commits/[^/]+/comments", "body"], ["comments/\\d+", "body"], ["releases(?:/\\d+)?", "body"],
  ]
  for (const [pattern, key] of patterns) if (new RegExp(`^${repo}${pattern}$`).test(endpoint)) return key
  return undefined
}

function fieldValue(flag, io) {
  const equals = flag.value.indexOf("=")
  const key = equals < 0 ? flag.value : flag.value.slice(0, equals)
  let value = equals < 0 ? undefined : flag.value.slice(equals + 1)
  const typed = ["--field", "-F"].includes(flag.name)
  const fromFile = typed && value?.startsWith("@")
  if (fromFile) value = readBody(value.slice(1), io)
  else if (typed && /^(?:true|false|null|-?\d+)$/.test(value)) value = JSON.parse(value)
  return { key, value, typed, fromFile }
}

function api(args, attribution, io) {
  const rest = args.slice(1)
  const { flags, positional } = parseArgs(rest, apiSpec)
  const option = (names) => flags.filter((flag) => names.includes(flag.name)).at(-1)
  if (enabled(option(["--help", "-h"]))) return args
  if (positional.length !== 1) blocked("Specify exactly one gh api endpoint.")
  const endpoint = positional[0].value.split("?")[0].replace(/^https?:\/\/[^/]+\//, "").replace(/^\/+|\/+$/g, "").replace(/^api\/v3\//, "")
  const fields = flags.filter((flag) => ["--field", "-F", "--raw-field", "-f"].includes(flag.name))
  const input = option(["--input"])
  const method = (option(["--method", "-X"])?.value ?? (fields.length || input ? "POST" : "GET")).toUpperCase()
  const graphql = endpoint === "graphql" || endpoint === "api/graphql"
  if (!graphql && ["GET", "HEAD", "OPTIONS", "DELETE"].includes(method)) return args
  const key = restPolicy(endpoint)
  if (!graphql && !key) {
    if (/^repos\/[^/]+\/[^/]+\/releases\/generate-notes$/.test(endpoint)) return args
    blocked(`Unsupported publishing API endpoint ${endpoint}; use a supported issue/PR/review/comment/release endpoint.`)
  }

  if (graphql) {
    let payload
    if (input) {
      try { payload = JSON.parse(readBody(input.value, io)) } catch { blocked("GraphQL --input must contain a JSON object.") }
    } else {
      payload = Object.create(null)
      for (const flag of fields) {
        const field = fieldValue(flag, io)
        if (!field.key || field.key.includes("[")) blocked("Use JSON --input for nested GraphQL variables.")
        if (Object.hasOwn(payload, field.key)) blocked(`Duplicate GraphQL field ${field.key}.`)
        payload[field.key] = field.value
      }
    }
    if (!payload || typeof payload !== "object" || typeof payload.query !== "string") blocked("Supply an explicit GraphQL query.")
    const variables = Object.assign(Object.create(null), input ? payload.variables ?? {} : Object.fromEntries(Object.entries(payload).filter(([name]) => !["query", "operationName"].includes(name))))
    const originalVariables = { ...variables }
    const result = rewriteGraphQL(payload.query, variables, payload.operationName, (body) => prepend(body, attribution))
    if (!result.changed) return args
    if (["GET", "HEAD", "OPTIONS", "DELETE"].includes(method)) blocked("Publishing GraphQL mutations must use POST.")
    const rewritten = { query: result.source, variables: result.variables }
    if (payload.operationName) rewritten.operationName = payload.operationName
    if (input) return ["api", ...replaceArgs(rest, [{ ...input, args: ["--input", io.temp(JSON.stringify({ ...payload, ...rewritten }))] }])]
    const replacements = []
    const added = []
    for (const [name, value] of Object.entries({ ...result.variables, query: result.source })) {
      if (value === (name === "query" ? payload.query : originalVariables[name])) continue
      const flag = fields.find((item) => item.value.startsWith(`${name}=`))
      if (typeof value !== "string") blocked("Use JSON --input for object-valued GraphQL variables.")
      const original = flag && fieldValue(flag, io)
      const args = [original?.typed && !original.fromFile ? "--field" : "--raw-field", `${name}=${value}`]
      if (flag) replacements.push({ ...flag, args })
      else added.push(...args)
    }
    return ["api", ...replaceArgs(rest, replacements), ...added]
  }

  if (input) {
    let payload
    try { payload = JSON.parse(readBody(input.value, io)) } catch { blocked("Publishing API --input must contain a JSON object.") }
    if (!payload || Array.isArray(payload) || typeof payload !== "object") blocked("Publishing API --input must contain a JSON object.")
    const walk = (value) => {
      if (Array.isArray(value)) return value.map(walk)
      if (!value || typeof value !== "object") return value
      return Object.fromEntries(Object.entries(value).map(([name, child]) => [name, name === key ? prepend(child, attribution) : walk(child)]))
    }
    const rewritten = walk(payload)
    if (method === "POST" && !Object.hasOwn(payload, key) && /\/(?:issues|pulls|releases|reviews|reviews\/\d+\/events)$/.test(endpoint)) rewritten[key] = prepend("", attribution)
    if (JSON.stringify(rewritten) === JSON.stringify(payload)) return args
    return ["api", ...replaceArgs(rest, [{ ...input, args: ["--input", io.temp(JSON.stringify(rewritten))] }])]
  }
  const replacements = []
  for (const flag of fields) {
    const equals = flag.value.indexOf("=")
    const name = equals < 0 ? flag.value : flag.value.slice(0, equals)
    if (name !== key && !name.endsWith(`[${key}]`)) continue
    const field = fieldValue(flag, io)
    replacements.push({ ...flag, args: [field.typed && !field.fromFile ? "--field" : "--raw-field", `${field.key}=${prepend(field.value, attribution)}`] })
  }
  const rewritten = ["api", ...replaceArgs(rest, replacements)]
  if (!fields.some((flag) => flag.value.startsWith(`${key}=`)) && method === "POST" && /\/(?:issues|pulls|releases|reviews|reviews\/\d+\/events)$/.test(endpoint)) {
    rewritten.push("--raw-field", `${key}=${prepend("", attribution)}`)
  }
  return rewritten
}

const readVerbs = new Set(["list", "view", "status", "diff", "checks", "download", "verify", "verify-asset", "checkout", "clone", "help"])
const nonPublishingNamespaces = new Set(["auth", "alias", "config", "completion", "cache", "attestation", "run", "workflow", "secret", "variable", "gpg-key", "ssh-key", "ruleset", "licenses", "search", "status", "browse"])
const coreNamespaces = new Set(["issue", "pr", "discussion", "release", "repo", "gist", "project", "extension", "codespace", "org", "label"])

export function rewriteCommand(args, attribution, io) {
  if (!args.length || ["--help", "-h", "--version", "version", "help"].includes(args[0])) return args
  // Repository flags are sometimes placed before the subcommand.
  let offset = 0
  while (args[offset]) {
    if (["-R", "--repo"].includes(args[offset])) offset += 2
    else if (/^(?:--repo=|-R.+)/.test(args[offset])) offset++
    else break
  }
  if (offset) return [...args.slice(0, offset), ...rewriteCommand(args.slice(offset), attribution, io)]
  const [namespace, originalVerb] = args
  const verb = namespace === "release" && originalVerb === "new" ? "create" : originalVerb
  if (coreNamespaces.has(namespace) && args.length === 2 && ["--help", "-h"].includes(verb)) return args
  if (namespace === "api") return api(args, attribution, io)
  if (nonPublishingNamespaces.has(namespace) || (coreNamespaces.has(namespace) && readVerbs.has(verb))) return args
  if (["issue", "pr", "discussion"].includes(namespace) && ["create", "edit", "comment", "review", "close", "reopen"].includes(verb)) {
    return native(args, namespace, verb, 2, attribution, io)
  }
  if (namespace === "release" && ["create", "edit"].includes(verb)) return native(args, namespace, verb, 2, attribution, io)
  if (["issue", "pr"].includes(namespace) && ["delete", "lock", "unlock", "pin", "unpin", "ready", "update-branch", "transfer"].includes(verb)) return args
  if (namespace === "pr" && verb === "merge" && !args.some((arg) => /^(?:--body(?:=|$)|-b)/.test(arg))) return args
  if (namespace === "repo" && !["create", "edit"].includes(verb)) return args
  if (namespace === "extension" && !["exec"].includes(verb)) return args
  blocked(`Unsupported gh publishing command or alias: ${namespace} ${verb ?? ""}. Expand aliases and use a supported Markdown posting command.`)
}
