package closevoiceadmissionpostgres

import (
	"context"
	topologycommandpostgres "voice-platform/backend/internal/channel/topology_command/postgres"
)

type receiptTransaction struct{ Transaction }

func (transaction receiptTransaction) QueryRow(ctx context.Context, statement string, arguments ...any) topologycommandpostgres.Row {
	return transaction.Transaction.QueryRow(ctx, statement, arguments...)
}
