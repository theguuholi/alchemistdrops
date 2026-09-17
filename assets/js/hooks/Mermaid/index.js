import mermaid from "mermaid"

const MIN_SCALE = 0.6
const MAX_SCALE = 2
const SCALE_STEP = 0.2
let diagramSequence = 0

const MermaidHook = {
  mounted() {
    this.diagrams = []
    this.currentTheme = this.effectiveTheme()
    this.renderDiagrams()
    this.observeTheme()
  },

  updated() {
    this.renderDiagrams()
  },

  destroyed() {
    this.themeObserver?.disconnect()
    this.colorSchemeQuery?.removeEventListener?.("change", this.colorSchemeListener)
    this.diagrams.forEach(diagram => diagram.cleanup.forEach(cleanup => cleanup()))
    this.diagrams = []
  },

  renderDiagrams() {
    this.el.querySelectorAll("pre.mermaid:not([data-blueprint-ready])").forEach(node => {
      node.dataset.blueprintReady = "true"
      const diagram = this.buildDiagram(node)
      this.diagrams.push(diagram)
      this.renderDiagram(diagram)
    })
  },

  buildDiagram(node) {
    const source = node.textContent.trim()
    const wrapper = document.createElement("section")
    wrapper.className = "mermaid-blueprint"
    wrapper.dataset.mermaidSource = source
    wrapper.setAttribute("aria-label", "Technical diagram")

    const viewport = document.createElement("div")
    viewport.className = "mermaid-viewport"
    const canvas = document.createElement("div")
    canvas.className = "mermaid-canvas"
    viewport.append(canvas)

    const toolbar = document.createElement("div")
    toolbar.className = "mermaid-toolbar"
    toolbar.setAttribute("aria-label", "Diagram controls")
    toolbar.append(
      this.controlButton("zoom-out", "Zoom out", "−"),
      this.controlButton("reset", "Reset zoom", "100%"),
      this.controlButton("zoom-in", "Zoom in", "+"),
      this.controlButton("expand", "Expand diagram", "↗")
    )

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

    wrapper.append(toolbar, viewport, dialog)
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

    this.bindControls(diagram)
    return diagram
  },

  controlButton(action, label, text) {
    const button = document.createElement("button")
    button.type = "button"
    button.dataset.action = action
    button.setAttribute("aria-label", label)
    button.title = label
    button.textContent = text
    return button
  },

  bindControls(diagram) {
    const onClick = event => {
      const action = event.target.closest("[data-action]")?.dataset.action

      if (action === "zoom-in") this.setScale(diagram, diagram.scale + SCALE_STEP)
      if (action === "zoom-out") this.setScale(diagram, diagram.scale - SCALE_STEP)
      if (action === "reset") this.setScale(diagram, 1)
      if (action === "expand") this.openDialog(diagram, event.target.closest("button"))
      if (action === "close") this.closeDialog(diagram)
    }

    const onKeydown = event => {
      if (event.key === "Escape" && diagram.dialog.hasAttribute("open")) {
        event.preventDefault()
        this.closeDialog(diagram)
      }
    }

    diagram.wrapper.addEventListener("click", onClick)
    diagram.dialog.addEventListener("keydown", onKeydown)
    diagram.cleanup.push(() => diagram.wrapper.removeEventListener("click", onClick))
    diagram.cleanup.push(() => diagram.dialog.removeEventListener("keydown", onKeydown))
  },

  setScale(diagram, requestedScale) {
    const bounded = Math.min(MAX_SCALE, Math.max(MIN_SCALE, requestedScale))
    diagram.scale = Math.round(bounded * 10) / 10
    diagram.canvas.style.transform = `scale(${diagram.scale})`
    diagram.wrapper.querySelector('[data-action="reset"]').textContent = `${Math.round(diagram.scale * 100)}%`
  },

  openDialog(diagram, trigger) {
    diagram.lastTrigger = trigger
    diagram.dialog.querySelector(".mermaid-dialog-canvas").innerHTML = diagram.canvas.innerHTML

    if (typeof diagram.dialog.showModal === "function") {
      diagram.dialog.showModal()
    } else {
      diagram.dialog.setAttribute("open", "")
    }

    diagram.dialog.querySelector('[data-action="close"]').focus()
  },

  closeDialog(diagram) {
    if (typeof diagram.dialog.close === "function") {
      diagram.dialog.close()
    } else {
      diagram.dialog.removeAttribute("open")
    }

    diagram.lastTrigger?.focus()
  },

  async renderDiagram(diagram) {
    const token = ++diagram.renderToken
    const theme = this.currentTheme
    mermaid.initialize(this.mermaidOptions(theme))

    try {
      const result = await mermaid.render(`mermaid-blueprint-${++diagramSequence}`, diagram.source)
      if (token !== diagram.renderToken) return

      diagram.canvas.innerHTML = result.svg
      diagram.canvas.classList.remove("is-error")
      this.setScale(diagram, diagram.scale)
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
  },

  mermaidOptions(theme) {
    const dark = theme === "dark"
    const styles = getComputedStyle(document.documentElement)
    const color = (name, fallback) => styles.getPropertyValue(name).trim() || fallback

    return {
      startOnLoad: false,
      securityLevel: "strict",
      theme: "base",
      themeVariables: {
        darkMode: dark,
        background: color("--color-base-100", dark ? "#111827" : "#ffffff"),
        primaryColor: color("--color-primary", dark ? "#38bdf8" : "#7c3aed"),
        primaryTextColor: color("--color-base-content", dark ? "#f8fafc" : "#272334"),
        primaryBorderColor: color("--color-secondary", dark ? "#c084fc" : "#7c3aed"),
        lineColor: color("--color-primary", dark ? "#38bdf8" : "#6d28d9"),
        secondaryColor: color("--color-base-200", dark ? "#172033" : "#f5f3ff"),
        tertiaryColor: color("--color-base-300", dark ? "#0f172a" : "#ecfeff"),
        clusterBkg: color("--color-base-200", dark ? "#172033" : "#f8fafc"),
        clusterBorder: color("--color-secondary", dark ? "#c084fc" : "#7c3aed"),
        edgeLabelBackground: color("--color-base-100", dark ? "#111827" : "#ffffff")
      }
    }
  },

  observeTheme() {
    this.themeObserver = new MutationObserver(() => this.themeChanged())
    this.themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-theme"]
    })

    this.colorSchemeQuery = window.matchMedia?.("(prefers-color-scheme: dark)")
    this.colorSchemeListener = () => this.themeChanged()
    this.colorSchemeQuery?.addEventListener?.("change", this.colorSchemeListener)
  },

  themeChanged() {
    const theme = this.effectiveTheme()
    if (theme === this.currentTheme) return

    this.currentTheme = theme
    this.diagrams.forEach(diagram => this.renderDiagram(diagram))
  },

  effectiveTheme() {
    const explicitTheme = document.documentElement.dataset.theme
    if (explicitTheme === "dark" || explicitTheme === "light") return explicitTheme
    return window.matchMedia?.("(prefers-color-scheme: dark)").matches ? "dark" : "light"
  }
}

export default MermaidHook
