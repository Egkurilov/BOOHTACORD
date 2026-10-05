import { expect,it } from 'vitest'
import { createConflictReview } from './state'
it('requires fetched current revision and retains all three independent values',()=>{
  const review=createConflictReview<string[]>()
  const old=['a','b'],draft=['b','a'];review.capture(old,draft);old.push('c');draft.push('d')
  expect(review.ready(2)).toBe(false);expect(review.before.value).toEqual(['a','b'])
  review.refresh(['a','c','b'],2);expect(review.ready(2)).toBe(true);expect(review.ready(3)).toBe(false)
  expect(review.proposed.value).toEqual(['b','a']);review.reset();expect(review.ready(2)).toBe(false)
})
