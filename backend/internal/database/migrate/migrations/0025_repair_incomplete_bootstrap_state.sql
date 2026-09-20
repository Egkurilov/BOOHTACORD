WITH lone_active_administrator AS (
    SELECT id
    FROM users
    WHERE role = 'ADMINISTRATOR'
      AND blocked_at IS NULL
      AND (
          SELECT COUNT(*)
          FROM users
          WHERE role = 'ADMINISTRATOR' AND blocked_at IS NULL
      ) = 1
), repaired AS (
    UPDATE bootstrap_state AS state
    SET administrator_id = administrator.id
    FROM lone_active_administrator AS administrator
    WHERE state.singleton = TRUE
      AND state.administrator_id IS NULL
    RETURNING administrator.id
)
INSERT INTO audit_events (event_type, target_user_id)
SELECT 'INITIAL_ADMINISTRATOR_CREATED', id FROM repaired;
