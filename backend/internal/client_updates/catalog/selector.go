package clientupdates

import "fmt"

var validPlatform = map[string]bool{"web": true, "android": true, "ios": true, "windows": true, "macos": true}
var validChannel = map[string]bool{"stable": true, "beta": true, "development": true}
var validArch = map[string]bool{"any": true, "arm64": true, "x64": true, "armv7": true}
var validAction = map[string]bool{"reload": true, "open_download_page": true, "open_store": true, "open_instructions": true}
var distributions = map[string]map[string]bool{
	"web":     {"browser": true, "development": true},
	"android": {"direct": true, "google_play": true, "development": true},
	"ios":     {"app_store": true, "testflight": true, "development": true},
	"windows": {"direct": true, "microsoft_store": true, "development": true},
	"macos":   {"direct": true, "mac_app_store": true, "development": true},
}

func (selector Selector) Validate() error {
	if !validPlatform[selector.Platform] || !validChannel[selector.Channel] || !validArch[selector.Arch] {
		return fmt.Errorf("invalid selector")
	}
	if !distributions[selector.Platform][selector.Distribution] {
		return fmt.Errorf("distribution does not match platform")
	}
	return nil
}

func (catalog Catalog) Select(selector Selector) (Policy, bool) {
	for _, entry := range catalog.Entries {
		if entry.Selector == selector {
			return Policy{ApplicationFamily: catalog.ApplicationFamily, CatalogRevision: catalog.Revision, Selector: selector, State: entry.State, Target: entry.Target}, true
		}
	}
	return Policy{ApplicationFamily: catalog.ApplicationFamily, CatalogRevision: catalog.Revision, Selector: selector, State: "unconfigured", Target: nil}, true
}
