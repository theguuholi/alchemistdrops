export function effectiveTheme() {
  const explicitTheme = document.documentElement.dataset.theme
  if (explicitTheme === "dark" || explicitTheme === "light") return explicitTheme

  return window.matchMedia?.("(prefers-color-scheme: dark)").matches ? "dark" : "light"
}

export function observeTheme(onChange) {
  const observer = new MutationObserver(onChange)
  observer.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ["data-theme"]
  })

  const colorSchemeQuery = window.matchMedia?.("(prefers-color-scheme: dark)")
  const colorSchemeListener = () => onChange()
  colorSchemeQuery?.addEventListener?.("change", colorSchemeListener)

  return {observer, colorSchemeQuery, colorSchemeListener}
}

const palettes = {
  light: {
    canvas: "#fcfcfe",
    processFill: "#eff6ff",
    processStroke: "#3b82f6",
    processText: "#172554",
    decisionFill: "#f5f3ff",
    decisionStroke: "#7c3aed",
    decisionText: "#2e1065",
    connector: "#64748b",
    edgeText: "#334155",
    clusterFill: "#f8fafc",
    clusterStroke: "#cbd5e1"
  },
  dark: {
    canvas: "#0b1220",
    processFill: "#172554",
    processStroke: "#60a5fa",
    processText: "#f8fafc",
    decisionFill: "#312e81",
    decisionStroke: "#a78bfa",
    decisionText: "#f5f3ff",
    connector: "#94a3b8",
    edgeText: "#e2e8f0",
    clusterFill: "#111827",
    clusterStroke: "#334155"
  }
}

export function mermaidOptions(theme) {
  const dark = theme === "dark"
  const colors = palettes[dark ? "dark" : "light"]

  return {
    startOnLoad: false,
    securityLevel: "strict",
    theme: "base",
    themeVariables: {
      darkMode: dark,
      fontSize: "18px",
      background: colors.canvas,
      primaryColor: colors.processFill,
      primaryTextColor: colors.processText,
      primaryBorderColor: colors.processStroke,
      lineColor: colors.connector,
      textColor: colors.edgeText,
      secondaryColor: colors.decisionFill,
      secondaryTextColor: colors.decisionText,
      secondaryBorderColor: colors.decisionStroke,
      tertiaryColor: colors.clusterFill,
      tertiaryTextColor: colors.edgeText,
      tertiaryBorderColor: colors.clusterStroke,
      clusterBkg: colors.clusterFill,
      clusterBorder: colors.clusterStroke,
      edgeLabelBackground: colors.canvas
    },
    themeCSS: `
      g.node:has(> polygon) > polygon {
        fill: ${colors.decisionFill} !important;
        stroke: ${colors.decisionStroke} !important;
      }

      g.node:has(> polygon) .nodeLabel {
        color: ${colors.decisionText} !important;
      }

      .edgeLabel {
        color: ${colors.edgeText} !important;
      }
    `
  }
}
