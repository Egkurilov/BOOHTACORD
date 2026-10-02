package clientupdates

import (
	"fmt"
	"net/url"
	"strings"
)

func validateURL(raw string, allowedHosts []string) error {
	if len(raw) == 0 || len(raw) > 2048 || strings.HasPrefix(raw, "//") {
		return fmt.Errorf("invalid URL length or form")
	}
	parsed, err := url.Parse(raw)
	if err != nil || parsed.User != nil || parsed.Fragment != "" {
		return fmt.Errorf("invalid URL")
	}
	if parsed.IsAbs() {
		if parsed.Scheme != "https" {
			return fmt.Errorf("absolute URL must use https")
		}
		for _, host := range allowedHosts {
			if strings.EqualFold(parsed.Hostname(), host) {
				return nil
			}
		}
		return fmt.Errorf("URL host is not allowlisted")
	}
	if !strings.HasPrefix(parsed.Path, "/") || strings.HasPrefix(parsed.Path, "//") {
		return fmt.Errorf("relative URL must be same-origin absolute path")
	}
	return nil
}
