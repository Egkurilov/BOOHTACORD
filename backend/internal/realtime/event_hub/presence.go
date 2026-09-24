package eventhub

import "sort"

func (hub *Hub) IsOnline(accountID string) bool {
	if hub == nil || accountID == "" {
		return false
	}
	hub.mu.Lock()
	defer hub.mu.Unlock()
	return hub.connections[accountID] > 0
}

func (hub *Hub) OnlineAccounts() []string {
	if hub == nil {
		return nil
	}
	hub.mu.Lock()
	defer hub.mu.Unlock()
	accounts := make([]string, 0, len(hub.connections))
	for accountID, connections := range hub.connections {
		if connections > 0 {
			accounts = append(accounts, accountID)
		}
	}
	sort.Strings(accounts)
	return accounts
}
