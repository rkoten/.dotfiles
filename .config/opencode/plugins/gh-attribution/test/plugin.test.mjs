import assert from "node:assert/strict"
import { test } from "node:test"
import { Effect } from "effect"
import plugin from "../index.ts"

async function setup(messages, models = []) {
  const hooks = {}
  const shell = { execute: (input) => Effect.gen(function* () {
    const event = { ...input, env: { PATH: "/usr/bin:/bin" } }
    yield* hooks.shell(event)
    return event
  }) }
  const ctx = {
    session: {
      hook: (name, callback) => Effect.sync(() => { hooks[name] = callback }),
      context: ({ sessionID }) => Effect.succeed(messages.filter((message) => message.sessionID === sessionID)).pipe(Effect.delay(sessionID.endsWith("a") ? 5 : 1)),
    },
    model: { list: () => Effect.succeed({ data: models }) },
    shell: { hook: (name, callback) => Effect.sync(() => { hooks.shell = callback }) },
    tool: { transform: (callback) => Effect.sync(() => callback({ update: (name, update) => { assert.equal(name, "shell"); update(shell) } })) },
  }
  await Effect.runPromise(plugin.effect(ctx))
  return { hooks, shell }
}

test("tool-local attribution is isolated across concurrent sessions and uses the issuing message", async () => {
  const modelA = { providerID: "openai", id: "model-a", variant: "high" }
  const modelB = { providerID: "anthropic", id: "model-b", variant: "low" }
  const { hooks, shell } = await setup([
    { type: "assistant", id: "message-a", sessionID: "session-a", model: modelA },
    { type: "assistant", id: "message-b", sessionID: "session-b", model: modelB },
  ])
  const input = { command: "gh pr comment --body text", cwd: "/project", timeout: 1000, shell: "/bin/zsh" }
  const results = await Effect.runPromise(Effect.all([
    shell.execute(input, { sessionID: "session-a", messageID: "message-a" }),
    shell.execute(input, { sessionID: "session-b", messageID: "message-b" }),
  ], { concurrency: "unbounded" }))
  assert.deepEqual(results.map((result) => JSON.parse(result.env.OPENCODE_GH_ATTRIBUTION)), [
    { model: "model-a", effort: "high" }, { model: "model-b", effort: "low" },
  ])
  for (const result of results) {
    assert.equal(result.command, input.command)
    assert.equal(result.cwd, input.cwd)
    assert.equal(result.timeout, input.timeout)
    assert.match(result.env.PATH, /gh-attribution\/bin:\/usr\/bin:\/bin$/)
  }
  const outside = { command: "gh auth status", env: { PATH: "/original" } }
  await Effect.runPromise(hooks.shell(outside))
  assert.deepEqual(outside.env, { PATH: "/original" })
})

test("request snapshots survive missing message state and expose actionable agent instructions", async () => {
  const { hooks, shell } = await setup([], [{ providerID: "openai", id: "model", variants: [{ id: "deep", settings: { reasoningEffort: "high" } }] }])
  const event = { sessionID: "session", model: { providerID: "openai", id: "model", variant: "deep" }, system: [], options: {} }
  await Effect.runPromise(hooks.context(event))
  // Later context hooks can still override the resolved effort for this request.
  event.options.reasoningEffort = "medium"
  const result = await Effect.runPromise(shell.execute({ command: "gh issue create" }, { sessionID: "session", messageID: "message" }))
  assert.deepEqual(JSON.parse(result.env.OPENCODE_GH_ATTRIBUTION), { model: "model", effort: "medium" })
  assert.match(event.system[0].text, /retry automatically/i)
  assert.match(event.system[0].text, /Do not bypass/)
})

test("an in-flight message is not relabelled when the session switches models", async () => {
  const { hooks, shell } = await setup([{ type: "assistant", id: "old", sessionID: "session", model: { providerID: "openai", id: "original", variant: "low" } }])
  await Effect.runPromise(hooks.context({ sessionID: "session", model: { providerID: "openai", id: "replacement", variant: "high" }, system: [], options: {} }))
  const result = await Effect.runPromise(shell.execute({ command: "gh issue comment" }, { sessionID: "session", messageID: "old" }))
  assert.deepEqual(JSON.parse(result.env.OPENCODE_GH_ATTRIBUTION), { model: "original", effort: "low" })
})
