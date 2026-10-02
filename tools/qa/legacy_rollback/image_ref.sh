#!/usr/bin/env bash

qa12_image_ref() {
  local root="$1" revision="$2" service="$3" receipt digest
  receipt="$root/$revision/$service.oci.json"
  [[ -r "$receipt" ]] || return 1
  digest="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["index_digest"])' "$receipt")" || return 1
  [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || return 1
  printf 'voice-platform-%s@%s\n' "$service" "$digest"
}
