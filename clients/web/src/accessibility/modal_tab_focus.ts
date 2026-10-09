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
  if (event.shiftKey && activeIndex <= 0) {
    event.preventDefault()
    focusable[focusable.length - 1].focus()
  } else if (!event.shiftKey && (activeIndex < 0 || activeIndex === focusable.length - 1)) {
    event.preventDefault()
    focusable[0].focus()
  }
}
