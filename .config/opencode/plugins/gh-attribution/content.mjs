export class AttributionError extends Error {}

export function blocked(reason) {
  throw new AttributionError(
    `${reason}\nNothing was posted. Retry automatically with the same intended content using ` +
      `an explicit --body/--body-file, or a supported gh api body. ` +
      `Do not discard generated content or bypass the attribution wrapper.`,
  )
}

function escapeHTML(value) {
  return String(value).replace(/[\r\n]/g, " ").replace(/[&<>"']/g, (character) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  })[character])
}

export function prepend(body, attribution) {
  if (typeof body !== "string") blocked("The publishing body must be a string.")
  if (!attribution?.model || !attribution?.effort) {
    blocked("The active OpenCode model/effort could not be resolved. Retry in a new shell tool call.")
  }
  const header = `<sup>[Posted by ${escapeHTML(attribution.model)} @ ${escapeHTML(attribution.effort)} via opencode]</sup>`
  // Only replace our own leading marker; quoted attribution elsewhere is ordinary content.
  const content = body.replace(/^<sup>\[Posted by [^\r\n]*?\]<\/sup>(?:\r?\n){0,2}/, "")
  return content ? `${header}\n\n${content}` : header
}

export function modelAttribution(reference, catalog = [], options = {}) {
  if (!reference?.id) return undefined
  const model = catalog.find((item) => item.id === reference.id && item.providerID === reference.providerID)
  const variant = model?.variants?.find((item) => item.id === reference.variant)
  const effort = (value) => value?.reasoningEffort ?? value?.effort ?? value?.reasoning?.effort ?? value?.reasoning_effort
  const selected = effort(options) ?? effort(variant?.body) ?? effort(variant?.settings) ??
    reference.variant ?? effort(model?.body) ?? effort(model?.settings) ?? "default"
  return { model: reference.id, effort: String(selected) }
}

// Parse argv, not shell text. Values that happen to look like flags must stay values.
export function parseArgs(args, specification) {
  const flags = []
  const positional = []
  let literal = false
  for (let index = 0; index < args.length; index++) {
    const argument = args[index]
    if (literal || argument === "-" || !argument.startsWith("-")) {
      positional.push({ value: argument, index })
      continue
    }
    if (argument === "--") {
      literal = true
      continue
    }
    const long = argument.startsWith("--")
    const equals = argument.indexOf("=")
    const name = long ? argument.slice(0, equals < 0 ? undefined : equals) : argument.slice(0, 2)
    const type = specification[name]
    if (!type) blocked(`Unsupported option ${name}; its effect on published content cannot be verified.`)
    let value
    const start = index
    if (type === "value") {
      value = long && equals >= 0 ? argument.slice(equals + 1) : !long && argument.length > 2
        ? argument.slice(2) : args[++index]
      if (value === undefined) blocked(`Missing value for ${name}.`)
    } else {
      if (!long && argument.length > 2) blocked(`Split the combined flags ${argument} into separate flags.`)
      value = long && equals >= 0 ? argument.slice(equals + 1) : "true"
    }
    flags.push({ name, value, start, end: index + 1 })
  }
  return { flags, positional }
}

export function flagSpec(values, booleans = "") {
  return Object.fromEntries([
    ...values.split(/\s+/).filter(Boolean).map((name) => [name, "value"]),
    ...booleans.split(/\s+/).filter(Boolean).map((name) => [name, "boolean"]),
  ])
}

export function replaceArgs(args, replacements) {
  const result = [...args]
  for (const replacement of [...replacements].sort((left, right) => right.start - left.start)) {
    result.splice(replacement.start, replacement.end - replacement.start, ...replacement.args)
  }
  return result
}
