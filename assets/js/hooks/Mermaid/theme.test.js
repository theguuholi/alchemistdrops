// @vitest-environment jsdom

import {afterEach, describe, expect, it} from "vitest"

import {mermaidOptions} from "./theme.js"

describe("Mermaid theme", () => {
  afterEach(() => document.documentElement.removeAttribute("style"))

  it("replaces unsupported CSS color formats with Mermaid-compatible fallbacks", () => {
    document.documentElement.style.setProperty("--color-base-100", "oklch(16% .02 240)")
    document.documentElement.style.setProperty("--color-primary", "rgb(14, 165, 233)")

    const options = mermaidOptions("dark")

    expect(options.themeVariables.background).toBe("#111827")
    expect(options.themeVariables.primaryColor).toBe("rgb(14, 165, 233)")
  })
})
