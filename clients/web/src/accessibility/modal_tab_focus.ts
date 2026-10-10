const focusableSelector = [
  'a[href]',
  'area[href]',
  'button:not(:disabled)',
  'input:not([type="hidden"]):not(:disabled)',
  'select:not(:disabled)',
  'textarea:not(:disabled)',
  'summary',
  'iframe',
  '[contenteditable="true"]',
  '[tabindex]:not([tabindex="-1"])',
].join(', ')

function isTabStop(element: HTMLElement, root: HTMLElement): boolean {
  if (element.tabIndex < 0) return false
  if (!(element instanceof HTMLInputElement) || element.type !== 'radio' || !element.name) return true

  const group = Array.from(root.querySelectorAll<HTMLInputElement>('input[type="radio"]')).filter((radio) =>
    radio.name === element.name && radio.form === element.form && !radio.disabled,
  )
  const checked = group.find((radio) => radio.checked)
  return (checked ?? group[0]) === element
}

export function containModalTab(event: KeyboardEvent, root: HTMLElement | null): void {
  if (event.key !== 'Tab' || !root) return

  const focusable = Array.from(root.querySelectorAll<HTMLElement>(focusableSelector)).filter((element) =>
    element.getClientRects().length > 0 &&
    getComputedStyle(element).visibility !== 'hidden' &&
    !element.closest('[inert], [aria-hidden="true"]') &&
    isTabStop(element, root),
  )
  if (!focusable.length) {
    event.preventDefault()
    root.focus()
    return
  }

  const activeIndex = focusable.indexOf(document.activeElement as HTMLElement)
  const offset = event.shiftKey ? -1 : 1
  const nextIndex = activeIndex < 0
    ? event.shiftKey ? focusable.length - 1 : 0
    : (activeIndex + offset + focusable.length) % focusable.length
  event.preventDefault()
  focusable[nextIndex].focus({ preventScroll: true })
}
