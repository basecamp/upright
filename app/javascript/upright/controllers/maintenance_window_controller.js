import { Controller } from "@hotwired/stimulus"

const HOUR = 60 * 60 * 1000

// Keeps a maintenance's end after its start: changing the start sets the end
// an hour later, and the +1h button moves the end an hour later.
export default class extends Controller {
  static targets = [ "start", "end" ]

  startChanged() {
    this.#setEnd(this.#start)
  }

  extend() {
    this.#setEnd(this.#end ?? this.#start)
  }

  fillEnd() {
    if (!this.endTarget.value) this.#setEnd(this.#start)
  }

  #setEnd(from) {
    if (from) this.endTarget.value = format(new Date(from.getTime() + HOUR))
  }

  get #start() {
    return parse(this.startTarget.value)
  }

  get #end() {
    return parse(this.endTarget.value)
  }
}

// datetime-local values are in local time, as YYYY-MM-DDTHH:MM.
function parse(value) {
  return value ? new Date(value) : null
}

function format(date) {
  const pad = (number) => String(number).padStart(2, "0")
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`
}
