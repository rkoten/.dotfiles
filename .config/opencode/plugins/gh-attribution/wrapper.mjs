import { accessSync, constants, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs"
import { delimiter, dirname, join } from "node:path"
import { tmpdir } from "node:os"
import { fileURLToPath } from "node:url"
import { spawn } from "node:child_process"
import { AttributionError } from "./content.mjs"
import { rewriteCommand } from "./commands.mjs"

const directory = dirname(fileURLToPath(import.meta.url))
const wrapperPath = realpathSync(join(directory, "bin", "gh"))

export function findGH(environment = process.env) {
  const candidates = environment.OPENCODE_GH_REAL
    ? [environment.OPENCODE_GH_REAL]
    : (environment.PATH ?? "").split(delimiter).map((path) => join(path || ".", "gh"))
  for (const candidate of candidates) {
    try {
      accessSync(candidate, constants.X_OK)
      if (realpathSync(candidate) !== wrapperPath) return realpathSync(candidate)
    } catch {}
  }
  throw new Error("Cannot find the real gh executable on PATH. Install GitHub CLI or set OPENCODE_GH_REAL to its absolute path.")
}

export async function main(args = process.argv.slice(2), environment = process.env) {
  let temporary
  let started = false
  try {
    const realGH = findGH(environment)
    let attribution
    try { attribution = JSON.parse(environment.OPENCODE_GH_ATTRIBUTION ?? "null") } catch {}
    let stdin
    const io = {
      stdin: () => stdin ??= readFileSync(0, "utf8"),
      temp: (content) => {
        // Use OpenCode's approved temp location when supplied, never a project body file.
        if (!temporary) {
          const base = environment.OPENCODE_GH_TMPDIR ?? join(tmpdir(), "opencode")
          mkdirSync(base, { recursive: true, mode: 0o700 })
          temporary = mkdtempSync(join(base, "gh-"))
        }
        const path = join(temporary, String(io.count++))
        writeFileSync(path, content, { mode: 0o600 })
        return path
      },
      count: 0,
    }
    const rewritten = rewriteCommand(args, attribution, io)
    return await new Promise((resolve, reject) => {
      const child = spawn(realGH, rewritten, { env: environment, stdio: [stdin === undefined ? "inherit" : "pipe", "inherit", "inherit"] })
      child.once("spawn", () => { started = true })
      const signals = ["SIGINT", "SIGTERM", "SIGHUP"]
      const forward = (signal) => { if (!child.killed) child.kill(signal) }
      const handlers = signals.map((signal) => [signal, () => forward(signal)])
      handlers.forEach(([signal, handler]) => process.on(signal, handler))
      const cleanup = () => handlers.forEach(([signal, handler]) => process.off(signal, handler))
      child.once("error", (error) => { cleanup(); reject(error) })
      child.once("exit", (code, signal) => {
        cleanup()
        resolve(code ?? ({ SIGINT: 130, SIGTERM: 143, SIGHUP: 129 }[signal] ?? 1))
      })
      // If we inspected stdin but did not replace its use (e.g. a GraphQL query), replay it.
      if (stdin !== undefined) { child.stdin.on("error", () => {}); child.stdin.end(stdin) }
    })
  } catch (error) {
    const message = error instanceof AttributionError ? error.message : started
      ? `gh failed after startup: ${error.message}. Check whether it posted before retrying.`
      : `Nothing was posted: ${error.message}`
    console.error(`[OpenCode gh attribution] ${message}`)
    return 1
  } finally {
    if (temporary) {
      try { rmSync(temporary, { recursive: true, force: true }) }
      catch (error) { console.error(`[OpenCode gh attribution] Warning: temporary-file cleanup failed: ${error.message}`) }
    }
  }
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) process.exitCode = await main()
