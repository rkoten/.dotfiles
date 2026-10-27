import { createRequire, registerHooks } from "node:module"
import { pathToFileURL } from "node:url"

// Mirror OpenCode's shared Effect runtime without installing another dependency.
const sdk = createRequire(import.meta.resolve("@opencode/plugin"))
let resolving = false
registerHooks({
  resolve(specifier, context, next) {
    if (!resolving && (specifier === "effect" || specifier.startsWith("effect/"))) {
      resolving = true
      try { return next(pathToFileURL(sdk.resolve(specifier)).href, context) }
      finally { resolving = false }
    }
    return next(specifier, context)
  },
})
