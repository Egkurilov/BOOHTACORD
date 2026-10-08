import type { RealtimeEvent } from '../realtime/realtime_client'
import { useAuthorDirectory } from '../identity/author_directory'
import { useMemberDirectory } from '../identity/member_directory'

interface DirectNavigation { error: string | null; refreshNavigation(): Promise<void> }
interface AuthorInvalidator { invalidate(memberId: string, revision: number): Promise<void> }
interface MemberInvalidator { error: string | null; invalidate(): Promise<void> }

export function createMemberProfileRefresh(
  authors: AuthorInvalidator = useAuthorDirectory(),
  members: MemberInvalidator = useMemberDirectory(),
) {
  return async (event: RealtimeEvent, direct: DirectNavigation): Promise<boolean> => {
    if (event.kind !== 'member.profile.updated') return false
    const { user_id: memberId, revision } = event.payload
    if (typeof memberId !== 'string' || typeof revision !== 'number') return false
    if (!Number.isSafeInteger(revision) || revision < 1) return false
    await authors.invalidate(memberId, revision)
    await Promise.all([members.invalidate(), direct.refreshNavigation()])
    if (members.error) throw new Error(members.error)
    if (direct.error) throw new Error(direct.error)
    return true
  }
}
