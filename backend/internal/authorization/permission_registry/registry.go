package permissionregistry

type Permission string

const (
	ChannelTextCreate  Permission = "channel.text.create"
	ChannelTextDelete  Permission = "channel.text.delete"
	ChannelVoiceCreate Permission = "channel.voice.create"
	ChannelVoiceDelete Permission = "channel.voice.delete"
	CategoryCreate     Permission = "category.create"
	CategoryDelete     Permission = "category.delete"
)

type Policy struct {
	TextCreate, TextDelete         bool
	VoiceCreate, VoiceDelete       bool
	CategoryCreate, CategoryDelete bool
	Revision                       int64
}

func MemberDefaults(revision int64) Policy {
	return Policy{TextCreate: true, VoiceCreate: true, CategoryCreate: true, Revision: revision}
}

func AdministratorPreset(revision int64) Policy {
	return Policy{
		TextCreate: true, TextDelete: true,
		VoiceCreate: true, VoiceDelete: true,
		CategoryCreate: true, CategoryDelete: true,
		Revision: revision,
	}
}

func (policy Policy) Values() map[Permission]bool {
	return map[Permission]bool{
		ChannelTextCreate: policy.TextCreate, ChannelTextDelete: policy.TextDelete,
		ChannelVoiceCreate: policy.VoiceCreate, ChannelVoiceDelete: policy.VoiceDelete,
		CategoryCreate: policy.CategoryCreate, CategoryDelete: policy.CategoryDelete,
	}
}

func (policy Policy) SameValues(other Policy) bool {
	policy.Revision, other.Revision = 0, 0
	return policy == other
}

func (policy Policy) AddsDeleteGrant(previous Policy) bool {
	return (!previous.TextDelete && policy.TextDelete) ||
		(!previous.VoiceDelete && policy.VoiceDelete) ||
		(!previous.CategoryDelete && policy.CategoryDelete)
}
