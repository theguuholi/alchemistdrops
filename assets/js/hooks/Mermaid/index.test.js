// @vitest-environment jsdom

import { beforeEach, describe, expect, it, vi } from "vitest"

const mermaidMock = vi.hoisted(() => ({
  initialize: vi.fn(),
  render: vi.fn()
}))

vi.mock("mermaid", () => ({ default: mermaidMock }))

import MermaidHook from "./index.js"

const flush = () => new Promise(resolve => setTimeout(resolve, 0))

function mountHook(source = "graph TD\n  A --> B") {
  document.body.innerHTML = `<article id="diagram-root"><pre class="mermaid">${source}</pre></article>`
  const hook = Object.assign({}, MermaidHook, { el: document.querySelector("#diagram-root") })
  hook.mounted()
  return hook
}

describe("Mermaid hook", () => {
  beforeEach(() => {
    document.documentElement.dataset.theme = "light"
    mermaidMock.initialize.mockReset()
    mermaidMock.render.mockReset()
    mermaidMock.render.mockResolvedValue({ svg: '<svg viewBox="0 0 100 80"><text>diagram</text></svg>' })
  })

  it("retains source and renders a blueprint toolbar once", async () => {
    const hook = mountHook()
    await flush()

    const blueprint = hook.el.querySelector(".mermaid-blueprint")
    expect(blueprint.dataset.mermaidSource).toContain("graph TD")
    expect(blueprint.querySelectorAll(".mermaid-toolbar")).toHaveLength(1)
    expect(blueprint.querySelectorAll(".mermaid-toolbar [data-action]")).toHaveLength(4)
    expect(mermaidMock.initialize).toHaveBeenCalledWith(
      expect.objectContaining({ theme: "base", startOnLoad: false })
    )

    hook.updated()
    await flush()
    expect(blueprint.querySelectorAll(".mermaid-toolbar")).toHaveLength(1)

    hook.el.innerHTML = '<pre class="mermaid">graph LR\n  C --> D</pre>'
    hook.updated()
    await flush()
    expect(hook.diagrams).toHaveLength(1)
    expect(hook.el.querySelector(".mermaid-blueprint").dataset.mermaidSource).toContain("graph LR")
  })

  it("zooms within bounds and resets the canvas", async () => {
    const hook = mountHook()
    await flush()
    const blueprint = hook.el.querySelector(".mermaid-blueprint")
    const canvas = blueprint.querySelector(".mermaid-canvas")

    for (let index = 0; index < 20; index++) {
      blueprint.querySelector('[data-action="zoom-in"]').click()
    }
    expect(canvas.style.transform).toBe("scale(2)")

    blueprint.querySelector('[data-action="reset"]').click()
    expect(canvas.style.transform).toBe("scale(1)")

    for (let index = 0; index < 20; index++) {
      blueprint.querySelector('[data-action="zoom-out"]').click()
    }
    expect(canvas.style.transform).toBe("scale(0.6)")
  })

  it("opens an accessible dialog and restores focus when it closes", async () => {
    const hook = mountHook()
    await flush()
    const expand = hook.el.querySelector('[data-action="expand"]')

    expand.focus()
    expand.click()

    const dialog = hook.el.querySelector("dialog.mermaid-dialog")
    expect(dialog.hasAttribute("open")).toBe(true)
    expect(dialog.getAttribute("aria-label")).toBe("Expanded diagram")

    dialog.querySelector('[data-action="close"]').click()
    expect(dialog.hasAttribute("open")).toBe(false)
    expect(document.activeElement).toBe(expand)

    expand.click()
    dialog.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }))
    expect(dialog.hasAttribute("open")).toBe(false)
    expect(document.activeElement).toBe(expand)
  })

  it("rerenders from original source when the effective theme changes", async () => {
    const hook = mountHook()
    await flush()
    mermaidMock.render.mockClear()

    document.documentElement.dataset.theme = "dark"
    await flush()

    expect(mermaidMock.render).toHaveBeenCalledWith(expect.any(String), expect.stringContaining("graph TD"))
    expect(mermaidMock.initialize).toHaveBeenLastCalledWith(
      expect.objectContaining({ theme: "base", themeVariables: expect.objectContaining({ darkMode: true }) })
    )
    hook.destroyed()
  })

  it("isolates parse errors and cleans up observers", async () => {
    mermaidMock.render.mockRejectedValueOnce(new Error("Parse error"))
    const hook = mountHook("not a diagram")
    await flush()

    expect(hook.el.querySelector(".mermaid-error[role='alert']").textContent).toContain(
      "Diagram could not be rendered"
    )

    const observer = hook.themeObserver
    const disconnect = vi.spyOn(observer, "disconnect")
    hook.destroyed()
    expect(disconnect).toHaveBeenCalledOnce()
  })
})
