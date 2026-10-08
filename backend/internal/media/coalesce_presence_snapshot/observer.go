package coalescepresencesnapshot

type Observer interface{ ObserveVoicePresenceGate(string) }

func (g *Gate) observe(outcome string) {
	if g.observer != nil {
		g.observer.ObserveVoicePresenceGate(outcome)
	}
}
