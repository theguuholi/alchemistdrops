import mermaid from "mermaid"

import {setScale} from "./diagram.js"
import {mermaidOptions} from "./theme.js"

let diagramSequence = 0

export async function renderDiagram(diagram, theme) {
  const token = ++diagram.renderToken
  mermaid.initialize(mermaidOptions(theme))

  try {
    const result = await mermaid.render(`mermaid-blueprint-${++diagramSequence}`, diagram.source)
    if (token !== diagram.renderToken) return

    diagram.canvas.innerHTML = result.svg
    diagram.canvas.classList.remove("is-error")
    setScale(diagram, diagram.scale)
    result.bindFunctions?.(diagram.canvas)
  } catch (_error) {
    if (token !== diagram.renderToken) return

    diagram.canvas.classList.add("is-error")
    diagram.canvas.innerHTML = `
      <div class="mermaid-error" role="alert">
        <strong>Diagram could not be rendered.</strong>
        <span>Check the Mermaid syntax and try again.</span>
      </div>
    `
  }
}
