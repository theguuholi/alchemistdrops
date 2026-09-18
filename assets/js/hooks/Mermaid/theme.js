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

export function mermaidOptions(theme) {
  const dark = theme === "dark"
  const styles = getComputedStyle(document.documentElement)
  const color = (name, fallback) => {
    const value = styles.getPropertyValue(name).trim()
    const supported = /^(?:#[\da-f]{3,8}|(?:rgb|rgba|hsl|hsla)\(|[a-z]+$)/i

    return supported.test(value) ? value : fallback
  }

  return {
    startOnLoad: false,
    securityLevel: "strict",
    theme: "base",
    themeVariables: {
      darkMode: dark,
      fontSize: "18px",
      background: color("--color-base-100", dark ? "#111827" : "#ffffff"),
      primaryColor: color("--color-primary", dark ? "#38bdf8" : "#7c3aed"),
      primaryTextColor: color("--color-primary-content", dark ? "#082f49" : "#ffffff"),
      primaryBorderColor: color("--color-secondary", dark ? "#c084fc" : "#7c3aed"),
      lineColor: color("--color-primary", dark ? "#38bdf8" : "#6d28d9"),
      secondaryColor: color("--color-base-200", dark ? "#172033" : "#f5f3ff"),
      tertiaryColor: color("--color-base-300", dark ? "#0f172a" : "#ecfeff"),
      clusterBkg: color("--color-base-200", dark ? "#172033" : "#f8fafc"),
      clusterBorder: color("--color-secondary", dark ? "#c084fc" : "#7c3aed"),
      edgeLabelBackground: color("--color-base-100", dark ? "#111827" : "#ffffff")
    }
  }
}
