package eventhub

import "testing"

func TestPermissionEventsRequireRolePermissionsCapability(t *testing.T) {
	hub := New(2)
	legacy := hub.Subscribe("legacy")
	capable := hub.SubscribeAccountWithCapabilities("new", Event{}, []string{"role_permissions_v1"})
	defer legacy.Close()
	defer capable.Close()
	hub.Publish(Event{Kind: "role.permissions.updated"})
	select {
	case <-legacy.Events():
		t.Fatal("legacy client received unknown event")
	default:
	}
	select {
	case event := <-capable.Events():
		if event.Kind != "role.permissions.updated" {
			t.Fatalf("event = %#v", event)
		}
	default:
		t.Fatal("capable client missed event")
	}
}
