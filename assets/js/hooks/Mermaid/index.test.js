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

  it("retains source and renders only the useful diagram controls", async () => {
    const hook = mountHook()
    await flush()

    const blueprint = hook.el.querySelector(".mermaid-blueprint")
    expect(blueprint.dataset.mermaidSource).toContain("graph TD")
    expect(blueprint.querySelectorAll(".mermaid-toolbar")).toHaveLength(1)
    expect(blueprint.querySelectorAll(".mermaid-toolbar [data-action]")).toHaveLength(3)
    expect(blueprint.querySelector('[data-action="expand"]')).toBeNull()
    expect(blueprint.querySelector("dialog")).toBeNull()
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
    expect(canvas.style.width).toBe("200%")
    expect(canvas.style.transform).toBe("")
    expect(blueprint.classList.contains("is-zoomed")).toBe(true)

    blueprint.querySelector('[data-action="reset"]').click()
    expect(canvas.style.width).toBe("100%")
    expect(blueprint.classList.contains("is-zoomed")).toBe(false)

    for (let index = 0; index < 20; index++) {
      blueprint.querySelector('[data-action="zoom-out"]').click()
    }
    expect(canvas.style.width).toBe("60%")
  })

  it("pans a zoomed diagram by dragging the viewport", async () => {
    const hook = mountHook()
    await flush()
    const blueprint = hook.el.querySelector(".mermaid-blueprint")
    const viewport = blueprint.querySelector(".mermaid-viewport")

    blueprint.querySelector('[data-action="zoom-in"]').click()
    viewport.dispatchEvent(new MouseEvent("pointerdown", { bubbles: true, clientX: 100, clientY: 90 }))
    viewport.dispatchEvent(new MouseEvent("pointermove", { bubbles: true, clientX: 70, clientY: 50 }))
    viewport.dispatchEvent(new MouseEvent("pointerup", { bubbles: true }))

    expect(viewport.scrollLeft).toBe(30)
    expect(viewport.scrollTop).toBe(40)
    expect(viewport.classList.contains("is-dragging")).toBe(false)
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
