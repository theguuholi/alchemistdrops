import {createDiagram, destroyDiagram} from "./diagram.js"
import {renderDiagram} from "./renderer.js"
import {effectiveTheme, observeTheme} from "./theme.js"

const MermaidHook = {
  mounted() {
    this.diagrams = []
    this.currentTheme = effectiveTheme()
    this.renderDiagrams()
    this.observeTheme()
  },

  updated() {
    this.renderDiagrams()
  },

  destroyed() {
    this.themeObserver?.disconnect()
    this.colorSchemeQuery?.removeEventListener?.("change", this.colorSchemeListener)
    this.diagrams.forEach(destroyDiagram)
    this.diagrams = []
  },

  renderDiagrams() {
    this.diagrams = this.diagrams.filter(diagram => {
      if (diagram.wrapper.isConnected) return true

      destroyDiagram(diagram)
      return false
    })

    this.el.querySelectorAll("pre.mermaid:not([data-blueprint-ready])").forEach(node => {
      node.dataset.blueprintReady = "true"
      const diagram = createDiagram(node)
      this.diagrams.push(diagram)
      this.renderDiagram(diagram)
    })
  },

  renderDiagram(diagram) {
    return renderDiagram(diagram, this.currentTheme)
  },

  observeTheme() {
    const subscription = observeTheme(() => this.themeChanged())
    this.themeObserver = subscription.observer
    this.colorSchemeQuery = subscription.colorSchemeQuery
    this.colorSchemeListener = subscription.colorSchemeListener
  },

  themeChanged() {
    const theme = effectiveTheme()
    if (theme === this.currentTheme) return

    this.currentTheme = theme
    this.diagrams.forEach(diagram => this.renderDiagram(diagram))
  }
}

export default MermaidHook
