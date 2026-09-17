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

  const dialog = buildDialog()
  wrapper.append(buildToolbar(), viewport, dialog)
  node.replaceWith(wrapper)

  const diagram = {
    source,
    wrapper,
    canvas,
    dialog,
    scale: 1,
    cleanup: [],
    renderToken: 0,
    lastTrigger: null
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
  diagram.canvas.style.transform = `scale(${diagram.scale})`
  diagram.wrapper.querySelector('[data-action="reset"]').textContent = `${Math.round(diagram.scale * 100)}%`
}

function buildToolbar() {
  const toolbar = document.createElement("div")
  toolbar.className = "mermaid-toolbar"
  toolbar.setAttribute("aria-label", "Diagram controls")
  toolbar.append(
    controlButton("zoom-out", "Zoom out", "−"),
    controlButton("reset", "Reset zoom", "100%"),
    controlButton("zoom-in", "Zoom in", "+"),
    controlButton("expand", "Expand diagram", "↗")
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

function buildDialog() {
  const dialog = document.createElement("dialog")
  dialog.className = "mermaid-dialog"
  dialog.setAttribute("aria-label", "Expanded diagram")
  dialog.innerHTML = `
    <div class="mermaid-dialog-header">
      <span>Diagram</span>
      <button type="button" data-action="close" aria-label="Close expanded diagram">Close</button>
    </div>
    <div class="mermaid-dialog-canvas"></div>
  `
  return dialog
}

function bindControls(diagram) {
  const onClick = event => {
    const action = event.target.closest("[data-action]")?.dataset.action

    if (action === "zoom-in") setScale(diagram, diagram.scale + SCALE_STEP)
    if (action === "zoom-out") setScale(diagram, diagram.scale - SCALE_STEP)
    if (action === "reset") setScale(diagram, 1)
    if (action === "expand") openDialog(diagram, event.target.closest("button"))
    if (action === "close") closeDialog(diagram)
  }

  const onKeydown = event => {
    if (event.key === "Escape" && diagram.dialog.hasAttribute("open")) {
      event.preventDefault()
      closeDialog(diagram)
    }
  }

  diagram.wrapper.addEventListener("click", onClick)
  diagram.dialog.addEventListener("keydown", onKeydown)
  diagram.cleanup.push(() => diagram.wrapper.removeEventListener("click", onClick))
  diagram.cleanup.push(() => diagram.dialog.removeEventListener("keydown", onKeydown))
}

function openDialog(diagram, trigger) {
  diagram.lastTrigger = trigger
  diagram.dialog.querySelector(".mermaid-dialog-canvas").innerHTML = diagram.canvas.innerHTML

  if (typeof diagram.dialog.showModal === "function") {
    diagram.dialog.showModal()
  } else {
    diagram.dialog.setAttribute("open", "")
  }

  diagram.dialog.querySelector('[data-action="close"]').focus()
}

function closeDialog(diagram) {
  if (typeof diagram.dialog.close === "function") {
    diagram.dialog.close()
  } else {
    diagram.dialog.removeAttribute("open")
  }

  diagram.lastTrigger?.focus()
}
