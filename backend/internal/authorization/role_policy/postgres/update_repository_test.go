package rolepolicypostgres

import (
	"context"
	"errors"
	"testing"

	permissionregistry "voice-platform/backend/internal/authorization/permission_registry"
	rolepolicy "voice-platform/backend/internal/authorization/role_policy"
)

func TestUpdateMemberRequiresRevisionAndDeleteGrantConfirmation(t *testing.T) {
	base := permissionregistry.MemberDefaults(3)
	for _, scenario := range []struct {
		command rolepolicy.UpdateCommand
		want    error
	}{
		{rolepolicy.UpdateCommand{ActorID: "admin", ExpectedRevision: 2, Policy: base}, rolepolicy.ErrRevisionConflict},
		{rolepolicy.UpdateCommand{ActorID: "admin", ExpectedRevision: 3, Policy: permissionregistry.Policy{TextCreate: true, TextDelete: true}}, rolepolicy.ErrDeleteGrantConfirmationRequired},
	} {
		transaction := newUpdateTransaction(base)
		_, err := New(&updateDatabase{transaction: transaction}).UpdateMember(context.Background(), scenario.command)
		if !errors.Is(err, scenario.want) || transaction.committed || !transaction.rolledBack {
			t.Fatalf("error = %v, transaction = %#v", err, transaction)
		}
	}
}

func TestUpdateMemberCommitsPolicyAndAuditOnce(t *testing.T) {
	base := permissionregistry.MemberDefaults(3)
	next := permissionregistry.Policy{TextCreate: true, TextDelete: true, VoiceCreate: true, CategoryCreate: true}
	transaction := newUpdateTransaction(base)
	transaction.updateRow = policyRow(withRevision(next, 4))
	result, err := New(&updateDatabase{transaction: transaction}).UpdateMember(context.Background(), rolepolicy.UpdateCommand{ActorID: "admin", ExpectedRevision: 3, Policy: next, ConfirmDeleteGrants: true})
	if err != nil || result.Revision != 4 || !transaction.committed || transaction.auditCalls != 1 || transaction.updateCalls != 1 {
		t.Fatalf("result = %#v, error = %v, transaction = %#v", result, err, transaction)
	}
}

func TestUpdateMemberNoopDoesNotWriteOrAudit(t *testing.T) {
	base := permissionregistry.MemberDefaults(3)
	transaction := newUpdateTransaction(base)
	result, err := New(&updateDatabase{transaction: transaction}).UpdateMember(context.Background(), rolepolicy.UpdateCommand{ActorID: "admin", ExpectedRevision: 3, Policy: base})
	if err != nil || result != base || transaction.updateCalls != 0 || transaction.auditCalls != 0 || !transaction.committed {
		t.Fatalf("result = %#v, error = %v, transaction = %#v", result, err, transaction)
	}
}

func withRevision(policy permissionregistry.Policy, revision int64) permissionregistry.Policy {
	policy.Revision = revision
	return policy
}
