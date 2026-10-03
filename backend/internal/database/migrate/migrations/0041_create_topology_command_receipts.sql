CREATE TABLE IF NOT EXISTS topology_command_receipts (
    actor_id UUID NOT NULL REFERENCES users(id),
    client_request_id UUID NOT NULL,
    operation TEXT NOT NULL,
    intent_hash TEXT NOT NULL CHECK (intent_hash ~ '^[0-9a-f]{64}$'),
    resource_id UUID NOT NULL,
    resource_type TEXT NOT NULL,
    result_state TEXT NOT NULL,
    topology_revision BIGINT NOT NULL CHECK (topology_revision > 0),
    response_status INTEGER NOT NULL CHECK (response_status BETWEEN 200 AND 299),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (actor_id, client_request_id)
);
