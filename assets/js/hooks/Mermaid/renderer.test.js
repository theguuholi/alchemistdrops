// @vitest-environment jsdom

import {expect, it, vi} from "vitest"

const mermaidMock = vi.hoisted(() => ({
  initialize: vi.fn(),
  render: vi.fn()
}))

vi.mock("mermaid", () => ({default: mermaidMock}))

it("disables Mermaid auto-rendering before the browser load event", async () => {
  await import("./renderer.js")

  expect(mermaidMock.initialize).toHaveBeenCalledWith({startOnLoad: false})
})
