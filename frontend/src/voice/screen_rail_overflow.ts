export interface HorizontalScrollMetrics {
  clientWidth: number
  scrollLeft: number
  scrollWidth: number
}

export function hasHorizontalOverflowAhead({ clientWidth, scrollLeft, scrollWidth }: HorizontalScrollMetrics): boolean {
  return scrollWidth - clientWidth - scrollLeft > 1
}

export function observeHorizontalOverflow(element: HTMLElement, onChange: (hasOverflow: boolean) => void): () => void {
  const update = () => onChange(hasHorizontalOverflowAhead(element))
  const resizeObserver = new ResizeObserver(update)
  const mutationObserver = new MutationObserver(update)
  resizeObserver.observe(element)
  mutationObserver.observe(element, { childList: true })
  element.addEventListener('scroll', update, { passive: true })
  update()
  return () => { resizeObserver.disconnect(); mutationObserver.disconnect(); element.removeEventListener('scroll', update) }
}
