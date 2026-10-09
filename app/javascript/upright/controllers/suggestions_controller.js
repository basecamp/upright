import { Controller } from "@hotwired/stimulus"

const VISIBLE = 4

// Offers past titles and messages while typing. Matching is fuzzy: the typed
// characters must appear in order, and matches at word starts or in runs score
// higher. When the best match continues the typed text, the rest is shown
// inline and Tab accepts it.
//
// With autofill, a change to the context fields replaces the text with the top
// suggestion unless someone has typed their own. A picked suggestion is still
// replaced, so a message picked for one status doesn't stay after the status
// changes.
export default class extends Controller {
  static targets = [ "input", "completion", "list" ]
  static values = { url: String, fields: Array, autofill: Boolean }

  connect() {
    this.suggestions = []
    this.matches = []
    this.active = -1
    this.edited = !this.autofillValue && this.inputTarget.value !== ""

    this.inputTarget.autocomplete = "off"
    this.inputTarget.setAttribute("role", "combobox")
    this.inputTarget.setAttribute("aria-autocomplete", "both")
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.listTarget.id ||= `${this.inputTarget.id}_suggestions`
    this.inputTarget.setAttribute("aria-controls", this.listTarget.id)
    this.#copyMetrics()

    this.form.addEventListener("change", this.#contextChanged)
    this.#load()
  }

  disconnect() {
    this.form.removeEventListener("change", this.#contextChanged)
    this.request?.abort()
  }

  input() {
    this.edited = true
    this.show()
  }

  show() {
    this.open = true
    this.#filter()
  }

  hide() {
    this.open = false
    this.#render()
  }

  navigate(event) {
    if (event.isComposing) return

    switch (event.key) {
      case "ArrowDown":
      case "ArrowUp":
        if (!this.#listed) return
        event.preventDefault()
        this.#highlight(event.key === "ArrowDown" ? this.active + 1 : this.active - 1)
        break
      case "Tab":
        if (event.shiftKey || !this.#listed || (this.active < 0 && !this.inputTarget.value)) return
        event.preventDefault()
        this.active >= 0 ? this.#pick(this.matches[this.active].text) : this.#acceptCompletion()
        break
      case "Enter":
        if (this.active < 0 || !this.#listed || event.metaKey || event.ctrlKey) return
        event.preventDefault()
        this.#pick(this.matches[this.active].text)
        break
      case "Escape":
        if (!this.#listed) return
        event.preventDefault()
        this.hide()
        break
      case "ArrowRight":
      case "End":
        if (this.completion && this.#caretAtEnd) {
          event.preventDefault()
          this.#acceptCompletion()
        }
        break
    }
  }

  sync() {
    this.completionTarget.scrollTop = this.inputTarget.scrollTop
    this.completionTarget.scrollLeft = this.inputTarget.scrollLeft
  }

  get form() {
    return this.inputTarget.form
  }

  #contextChanged = (event) => {
    if (this.fieldsValue.includes(event.target.name)) this.#load({ autofill: this.autofillValue && !this.edited })
  }

  async #load({ autofill = false } = {}) {
    this.request?.abort()
    this.request = new AbortController()

    const url = new URL(this.urlValue, window.location.href)
    const data = new FormData(this.form)
    this.fieldsValue.forEach(name => data.getAll(name).forEach(value => url.searchParams.append(name, value)))

    try {
      const response = await fetch(url, { headers: { Accept: "application/json" }, signal: this.request.signal })
      if (!response.ok) return
      this.suggestions = (await response.json()).map((suggestion, rank) => ({ ...suggestion, rank }))
    } catch (error) {
      if (error.name === "AbortError") return
      throw error
    }

    if (autofill && this.suggestions.length) this.inputTarget.value = this.suggestions[0].text
    this.#filter()
  }

  #filter() {
    const query = this.inputTarget.value.trim()

    this.matches = this.suggestions
      .map(suggestion => ({ ...suggestion, match: fuzzy(query, suggestion.text) }))
      .filter(suggestion => suggestion.match && suggestion.text !== this.inputTarget.value)
      .sort((a, b) => (b.match.score - a.match.score) || (a.rank - b.rank))
      .slice(0, VISIBLE)

    this.active = -1
    this.#render()
  }

  #render() {
    const best = this.matches[0]
    const value = this.inputTarget.value
    const continues = this.open && value && best && this.#caretAtEnd && best.text.toLowerCase().startsWith(value.toLowerCase())
    this.completion = continues ? best.text.slice(value.length) : ""

    const rest = document.createElement("span")
    rest.textContent = this.completion
    this.completionTarget.replaceChildren(document.createTextNode(value), rest)
    this.sync()

    this.listTarget.replaceChildren(...this.matches.map((suggestion, index) => this.#option(suggestion, index)))
    this.listTarget.hidden = !this.#listed
    this.inputTarget.setAttribute("aria-expanded", String(this.#listed))
    this.#highlight(this.active)
  }

  #option(suggestion, index) {
    const option = document.createElement("li")
    option.className = "picker__option"
    option.id = `${this.listTarget.id}_${index}`
    option.setAttribute("role", "option")
    option.addEventListener("mousedown", event => {
      event.preventDefault()
      this.#pick(suggestion.text)
    })

    const text = document.createElement("span")
    text.className = "picker__text"
    let run = ""
    let marked = false
    const flush = () => {
      if (!run) return
      text.append(marked ? Object.assign(document.createElement("mark"), { textContent: run }) : run)
      run = ""
    }
    suggestion.text.split("").forEach((char, position) => {
      const isMatch = suggestion.match.positions.has(position)
      if (isMatch !== marked) { flush(); marked = isMatch }
      run += char
    })
    flush()
    option.append(text)

    if (suggestion.uses > 0) {
      const uses = document.createElement("span")
      uses.className = "picker__uses"
      uses.textContent = `${suggestion.uses}×`
      uses.title = `Used ${suggestion.uses} ${suggestion.uses === 1 ? "time" : "times"}`
      option.append(uses)
    }

    return option
  }

  #highlight(index) {
    const count = this.matches.length
    this.active = count ? Math.max(-1, Math.min(index, count - 1)) : -1

    this.listTarget.querySelectorAll("[role=option]").forEach((option, position) => {
      option.setAttribute("aria-selected", String(position === this.active))
    })

    if (this.active >= 0) {
      this.inputTarget.setAttribute("aria-activedescendant", `${this.listTarget.id}_${this.active}`)
    } else {
      this.inputTarget.removeAttribute("aria-activedescendant")
    }
  }

  #pick(text) {
    this.edited = false
    this.inputTarget.value = text
    this.inputTarget.setSelectionRange(text.length, text.length)
    this.inputTarget.focus()
    this.hide()
  }

  #acceptCompletion() {
    this.#pick(this.completion ? this.inputTarget.value + this.completion : this.matches[0].text)
  }

  #copyMetrics() {
    const style = getComputedStyle(this.inputTarget)
    const properties = [ "fontFamily", "fontSize", "fontWeight", "letterSpacing", "lineHeight", "boxSizing",
      "paddingTop", "paddingRight", "paddingBottom", "paddingLeft",
      "borderTopWidth", "borderRightWidth", "borderBottomWidth", "borderLeftWidth" ]

    properties.forEach(property => this.completionTarget.style[property] = style[property])
    this.completionTarget.style.borderStyle = "solid"
    this.completionTarget.style.borderColor = "transparent"
    this.completionTarget.style.whiteSpace = this.inputTarget.tagName === "TEXTAREA" ? "pre-wrap" : "pre"
  }

  get #listed() {
    return this.open && this.matches.length > 0
  }

  get #caretAtEnd() {
    return this.inputTarget.selectionStart === this.inputTarget.value.length
  }
}

// Each space-separated term must match, in any order. Within a term the
// characters must appear in order, not necessarily next to each other.
function fuzzy(query, text) {
  const haystack = text.toLowerCase()
  const positions = new Set()
  let score = 0

  for (const term of query.toLowerCase().split(/\s+/).filter(Boolean)) {
    const match = bestMatch(term, haystack)
    if (!match) return null

    score += match.score
    match.positions.forEach(position => positions.add(position))
  }

  return { score, positions }
}

function bestMatch(term, haystack) {
  let best = null

  for (let start = haystack.indexOf(term[0]); start !== -1; start = haystack.indexOf(term[0], start + 1)) {
    const match = matchFrom(term, haystack, start)
    if (!match) break
    if (!best || match.score > best.score) best = match
  }

  return best
}

function matchFrom(term, haystack, start) {
  const positions = []
  let score = 0
  let index = start

  for (const char of term) {
    index = haystack.indexOf(char, index)
    if (index === -1) return null

    const previous = positions.at(-1)
    score += 1
    if (index === 0 || /[^\p{L}\p{N}]/u.test(haystack[index - 1])) score += 8
    if (previous !== undefined) score += index === previous + 1 ? 4 : -Math.min(index - previous - 1, 10) * 0.2

    positions.push(index)
    index += 1
  }

  return { score, positions }
}
