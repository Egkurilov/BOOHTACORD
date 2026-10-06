package causalreference

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"strings"
	"time"
)

type Proof struct {
	Cause
	Expires int64 `json:"expires"`
}

func Sign(secret, account string, cause Cause, now time.Time) string {
	if secret == "" || account == "" || !cause.Valid() {
		return ""
	}
	body, _ := json.Marshal(Proof{cause, now.Add(7 * 24 * time.Hour).Unix()})
	text := base64.RawURLEncoding.EncodeToString(body)
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte("boohtacord/causality/v1\x00" + account + "\x00" + text))
	return text + "." + base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}
func Verify(secret, account, value string, now time.Time) (Cause, bool) {
	if secret == "" || account == "" || len(value) > 512 {
		return Cause{}, false
	}
	body, signature, ok := strings.Cut(value, ".")
	if !ok {
		return Cause{}, false
	}
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte("boohtacord/causality/v1\x00" + account + "\x00" + body))
	signed, err := base64.RawURLEncoding.DecodeString(signature)
	if err != nil || !hmac.Equal(signed, mac.Sum(nil)) {
		return Cause{}, false
	}
	data, err := base64.RawURLEncoding.DecodeString(body)
	if err != nil {
		return Cause{}, false
	}
	var proof Proof
	if json.Unmarshal(data, &proof) != nil || !proof.Cause.Valid() || proof.Expires < now.Unix() || proof.Expires > now.Add(7*24*time.Hour).Unix() {
		return Cause{}, false
	}
	return proof.Cause, true
}
