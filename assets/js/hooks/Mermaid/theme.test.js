// @vitest-environment jsdom

import {describe, expect, it} from "vitest"

import {mermaidOptions} from "./theme.js"

describe("Mermaid theme", () => {
  it("uses the approved high-contrast dark palette", () => {
    const options = mermaidOptions("dark")

    expect(options.themeVariables).toMatchObject({
      background: "#0b1220",
      primaryColor: "#172554",
      primaryTextColor: "#f8fafc",
      primaryBorderColor: "#60a5fa",
      lineColor: "#94a3b8"
    })
    expect(options.themeCSS).toContain("fill: #312e81")
    expect(options.themeCSS).toContain("color: #f5f3ff")
  })

  it("uses the approved high-contrast light palette", () => {
    const options = mermaidOptions("light")

    expect(options.themeVariables).toMatchObject({
      background: "#fcfcfe",
      primaryColor: "#eff6ff",
      primaryTextColor: "#172554",
      primaryBorderColor: "#3b82f6",
      lineColor: "#64748b"
    })
    expect(options.themeCSS).toContain("fill: #f5f3ff")
    expect(options.themeCSS).toContain("color: #2e1065")
  })
})
