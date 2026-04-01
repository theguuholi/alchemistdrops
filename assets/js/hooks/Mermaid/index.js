import mermaid from "mermaid"

mermaid.initialize({ startOnLoad: false, theme: "neutral" })

const MermaidHook = {
  mounted() {
    this.renderDiagrams()
  },
  updated() {
    this.renderDiagrams()
  },
  renderDiagrams() {
    const nodes = this.el.querySelectorAll("pre.mermaid:not([data-processed])")
    if (nodes.length > 0) {
      mermaid.run({ nodes: Array.from(nodes) })
    }
  }
}

export default MermaidHook
