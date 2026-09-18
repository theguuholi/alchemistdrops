const MIN_SCALE = 0.6
const MAX_SCALE = 2
const SCALE_STEP = 0.2

export function createDiagram(node) {
  const source = node.textContent.trim()
  const wrapper = document.createElement("section")
  wrapper.className = "mermaid-blueprint"
  wrapper.dataset.mermaidSource = source
  wrapper.setAttribute("aria-label", "Technical diagram")

  const canvas = document.createElement("div")
  canvas.className = "mermaid-canvas"

  const viewport = document.createElement("div")
  viewport.className = "mermaid-viewport"
  viewport.append(canvas)

  wrapper.append(buildToolbar(), viewport)
  node.replaceWith(wrapper)

  const diagram = {
    source,
    wrapper,
    viewport,
    canvas,
    scale: 1,
    cleanup: [],
    renderToken: 0
  }

  bindControls(diagram)
  return diagram
}

export function destroyDiagram(diagram) {
  diagram.renderToken += 1
  diagram.cleanup.forEach(cleanup => cleanup())
  diagram.cleanup = []
}

export function setScale(diagram, requestedScale) {
  const boundedScale = Math.min(MAX_SCALE, Math.max(MIN_SCALE, requestedScale))
  diagram.scale = Math.round(boundedScale * 10) / 10
  diagram.canvas.style.width = `${Math.round(diagram.scale * 100)}%`
  diagram.wrapper.classList.toggle("is-zoomed", diagram.scale > 1)
  diagram.wrapper.querySelector('[data-action="reset"]').textContent = `${Math.round(diagram.scale * 100)}%`
}

function buildToolbar() {
  const toolbar = document.createElement("div")
  toolbar.className = "mermaid-toolbar"
  toolbar.setAttribute("aria-label", "Diagram controls")
  toolbar.append(
    controlButton("zoom-out", "Zoom out", "−"),
    controlButton("reset", "Reset zoom", "100%"),
    controlButton("zoom-in", "Zoom in", "+")
  )
  return toolbar
}

function controlButton(action, label, text) {
  const button = document.createElement("button")
  button.type = "button"
  button.dataset.action = action
  button.setAttribute("aria-label", label)
  button.title = label
  button.textContent = text
  return button
}

function bindControls(diagram) {
  const onClick = event => {
    const action = event.target.closest("[data-action]")?.dataset.action

    if (action === "zoom-in") setScale(diagram, diagram.scale + SCALE_STEP)
    if (action === "zoom-out") setScale(diagram, diagram.scale - SCALE_STEP)
    if (action === "reset") setScale(diagram, 1)
  }

  const drag = {active: false, x: 0, y: 0, left: 0, top: 0}
  const startDragging = event => {
    if (event.button !== 0 || diagram.scale <= 1) return

    drag.active = true
    drag.x = event.clientX
    drag.y = event.clientY
    drag.left = diagram.viewport.scrollLeft
    drag.top = diagram.viewport.scrollTop
    diagram.viewport.classList.add("is-dragging")
    diagram.viewport.setPointerCapture?.(event.pointerId)
  }
  const dragDiagram = event => {
    if (!drag.active) return

    diagram.viewport.scrollLeft = drag.left + drag.x - event.clientX
    diagram.viewport.scrollTop = drag.top + drag.y - event.clientY
    event.preventDefault()
  }
  const stopDragging = event => {
    if (!drag.active) return

    drag.active = false
    diagram.viewport.classList.remove("is-dragging")
    if (diagram.viewport.hasPointerCapture?.(event.pointerId)) {
      diagram.viewport.releasePointerCapture(event.pointerId)
    }
  }

  diagram.wrapper.addEventListener("click", onClick)
  diagram.viewport.addEventListener("pointerdown", startDragging)
  diagram.viewport.addEventListener("pointermove", dragDiagram)
  diagram.viewport.addEventListener("pointerup", stopDragging)
  diagram.viewport.addEventListener("pointercancel", stopDragging)
  diagram.cleanup.push(() => diagram.wrapper.removeEventListener("click", onClick))
  diagram.cleanup.push(() => diagram.viewport.removeEventListener("pointerdown", startDragging))
  diagram.cleanup.push(() => diagram.viewport.removeEventListener("pointermove", dragDiagram))
  diagram.cleanup.push(() => diagram.viewport.removeEventListener("pointerup", stopDragging))
  diagram.cleanup.push(() => diagram.viewport.removeEventListener("pointercancel", stopDragging))
}
