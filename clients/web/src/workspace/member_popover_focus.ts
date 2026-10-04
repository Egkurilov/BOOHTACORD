export function focusMemberPopover(panel: HTMLElement | null, modal: boolean): void {
  if (modal) panel?.focus()
  else (panel?.querySelector<HTMLButtonElement>('.member-popover-actions button') ?? panel?.querySelector<HTMLButtonElement>('header button'))?.focus()
}
