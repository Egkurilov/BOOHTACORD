package eventhub

func (hub *Hub) SubscribeAccountWithCapabilities(accountID string, onlineEvent Event, capabilities []string) *Subscription {
	set := make(map[string]struct{}, len(capabilities))
	for _, capability := range capabilities {
		if capability != "" {
			set[capability] = struct{}{}
		}
	}
	if onlineEvent.Kind == "" {
		return hub.subscribe(accountID, nil, set)
	}
	return hub.subscribe(accountID, &onlineEvent, set)
}
