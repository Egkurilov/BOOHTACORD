# Cached ACL revocation fixture

Route: tools/qa/next_client_acceptance/cache_acl.mjs; small_direct CI fixture correction.

Actual hosted run 37850555405 passed headed hidden/visible, managed uploads and protected unread, then failed PostgreSQL voice_leases_check. The fixture wrote revoked_at without the required revocation_reason. Migration 0010 requires both values together; the production constraint is preserved.

The owned synthetic account revocation now writes KICK with revoked_at in the same statement. A UUID guard rejects SQL interpolation. Node tests: missing helper RED, implemented helper 2 PASS. Production API, SFU behavior and the cache-ACL assertion are unchanged.

Full actual hosted scenario: pending rerun on this commit. This source check alone does not prove SFU ACL acceptance.
