import { Plugin } from "@opencode/plugin/effect"
import type { Model } from "@opencode/plugin/effect"
import type { ToolHooks } from "@opencode/plugin/effect/tool"
import { Context, Effect } from "effect"
import { delimiter, dirname, join } from "node:path"
import { tmpdir } from "node:os"
import { fileURLToPath } from "node:url"
import { modelAttribution } from "./content.mjs"

type Actor = Pick<ToolHooks["execute.before"], "sessionID" | "messageID">
type Snapshot = { model: Model.Ref; options: Record<string, unknown> }

const Actor = Context.Reference<Actor | undefined>("gh-attribution/actor", { defaultValue: () => undefined })
const bin = join(dirname(fileURLToPath(import.meta.url)), "bin")

export default Plugin.define({
  id: "gh-attribution",
  effect: (ctx) => Effect.gen(function* () {
    const requests = new Map<string, Snapshot>()
    const attributions = new Map<string, ReturnType<typeof modelAttribution>>()
    const remember = <T>(map: Map<string, T>, key: string, value: T) => {
      if (map.size >= 128) map.delete(map.keys().next().value!)
      map.set(key, value)
    }

    yield* ctx.session.hook("context", (event) => Effect.sync(() => {
      remember(requests, event.sessionID, { model: event.model, options: event.options })
      event.system.push({
        type: "text",
        text: "GitHub publishing: invoke gh through PATH, never by an absolute path or a replacement PATH. " +
          "The gh-attribution wrapper prepends the active model/effort automatically. " +
          "If it refuses a publishing form, retry automatically using its supported explicit-body form, " +
          "preserving all intended content. Do not bypass the wrapper or retry a command that already posted successfully.",
      })
    }))

    // Fiber-local context reaches background shell creation without leaking across sessions.
    // Wrapping the executor leaves the original shell permission checks and command intact.
    yield* ctx.tool.transform((editor) => {
      editor.update("shell", (tool) => {
        const execute = tool.execute
        tool.execute = (input, context) => Effect.suspend(() => execute(input, context)).pipe(
          Effect.provideService(Actor, context),
        )
      })
    })

    yield* ctx.shell.hook("create.before", (event) => Effect.gen(function* () {
      const actor = yield* Actor
      if (!actor) return
      const key = `${actor.sessionID}/${actor.messageID}`
      if (!attributions.has(key)) {
        const messages = yield* ctx.session.context({ sessionID: actor.sessionID }).pipe(Effect.orElseSucceed(() => []))
        const message = messages.find((item) => item.id === actor.messageID && item.type === "assistant")
        const snapshot = requests.get(actor.sessionID)
        const reference = message?.type === "assistant" ? message.model : snapshot?.model
        const models = yield* ctx.model.list().pipe(Effect.orElseSucceed(() => ({ data: [] })))
        const sameRequestModel = reference && snapshot && reference.providerID === snapshot.model.providerID &&
          reference.id === snapshot.model.id && reference.variant === snapshot.model.variant
        remember(attributions, key, modelAttribution(reference, models.data, sameRequestModel ? snapshot.options : {}))
      }
      const attribution = attributions.get(key)
      const path = event.env.PATH ?? process.env.PATH ?? ""
      event.env.PATH = [bin, ...path.split(delimiter).filter((entry) => entry !== bin)].join(delimiter)
      event.env.OPENCODE_GH_ATTRIBUTION = attribution ? JSON.stringify(attribution) : undefined
      event.env.OPENCODE_GH_TMPDIR ??= join(tmpdir(), "opencode")
    }))
  }),
})
