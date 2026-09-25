// Go validates these fields with utf8.RuneCountInString, not UTF-16 input length.
export function validCodePointLength(value: string, minimum: number, maximum: number): boolean {
  const length = Array.from(value).length
  return length >= minimum && length <= maximum
}
