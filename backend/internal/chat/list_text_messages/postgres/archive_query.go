package listtextmessagespostgres

import "strings"

// The data statement must recheck the archive ACL even after the availability
// probe; a block or restore may commit between those two statements.
func archiveHistoryQuery(after bool) string {
	return strings.Replace(historyQuery(after), "WHERE messages.channel_id = $1", `WHERE messages.channel_id = $1
  AND EXISTS(SELECT 1 FROM channels JOIN users ON users.id=$5
    WHERE channels.id=$1 AND channels.kind='TEXT' AND channels.archived_at IS NOT NULL
    AND channels.readonly_archive AND users.blocked_at IS NULL)`, 1)
}
