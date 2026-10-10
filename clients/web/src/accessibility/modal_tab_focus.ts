const focusableSelector = [
  'a[href]',
  'area[href]',
  'button:not(:disabled)',
  'input:not([type="hidden"]):not(:disabled)',
  'select:not(:disabled)',
  'textarea:not(:disabled)',
  'iframe',
  '[contenteditable="true"]',
  '[tabindex]:not([tabindex="-1"])',
].join(', ')

export function containModalTab(event: KeyboardEvent, root: HTMLElement | null): void {
  if (event.key !== 'Tab' || !root) return

  const focusable = Array.from(root.querySelectorAll<HTMLElement>(focusableSelector)).filter((element) =>
    element.getClientRects().length > 0 &&
    getComputedStyle(element).visibility !== 'hidden' &&
    !element.closest('[inert], [aria-hidden="true"]'),
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
