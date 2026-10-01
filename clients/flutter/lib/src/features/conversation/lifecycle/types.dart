enum MessageEditStatus { saved, conflict, error, stale }

typedef MessageEditOutcome = ({MessageEditStatus kind, String? message});
