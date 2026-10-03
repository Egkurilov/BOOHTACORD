package eventhub

func (hub *Hub) Publish(event Event) {
	hub.publishMu.Lock()
	defer hub.publishMu.Unlock()
	ctx, cancel := backgroundWriteContext()
	defer cancel()
	var err error
	event, err = hub.persist(ctx, event, nil, false)
	if err != nil {
		return
	}
	hub.mu.Lock()
	defer hub.mu.Unlock()
	hub.publishLocked(event)
}

func (hub *Hub) publishLocked(event Event) {
	for subscription := range hub.subscribers {
		if !subscription.dropped {
			hub.deliverLocked(subscription, event)
		}
	}
}

func (hub *Hub) deliverLocked(subscription *Subscription, event Event) {
	if permissionCapabilityRequired(event.Kind) {
		if _, supported := subscription.capabilities["role_permissions_v1"]; !supported {
			return
		}
	}
	select {
	case subscription.events <- event:
	default:
		subscription.dropped = true
		subscription.overflowed <- struct{}{}
	}
}

func permissionCapabilityRequired(kind string) bool {
	return kind == "role.permissions.updated" || kind == "auth.permissions.invalidated"
}
