package permissionregistry

import "testing"

func TestMemberDefaultsAndAdministratorPreset(t *testing.T) {
	wantMember := Policy{TextCreate: true, VoiceCreate: true, CategoryCreate: true, Revision: 1}
	if got := MemberDefaults(1); got != wantMember {
		t.Fatalf("MemberDefaults() = %#v", got)
	}
	admin := AdministratorPreset(7)
	if admin.Revision != 7 || !admin.TextCreate || !admin.TextDelete || !admin.VoiceCreate || !admin.VoiceDelete || !admin.CategoryCreate || !admin.CategoryDelete {
		t.Fatalf("AdministratorPreset() = %#v", admin)
	}
}

func TestPolicyValuesExposeExactlySixCanonicalPermissions(t *testing.T) {
	values := (Policy{TextCreate: true, VoiceDelete: true, Revision: 3}).Values()
	if len(values) != 6 || !values[ChannelTextCreate] || !values[ChannelVoiceDelete] || values[CategoryDelete] {
		t.Fatalf("Values() = %#v", values)
	}
}
