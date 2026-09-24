package listtopology

import "context"

type Channel struct {
	ID, Name        string
	Kind            string
	Position        int
	AdmissionClosed bool
	UnreadCount     int64
	MentionCount    int64
}
type Category struct {
	ID, Name string
	Position int
	Channels []Channel
}
type Result struct {
	Revision   int64
	Categories []Category
}
type Input struct{ ActorID string }
type Request struct{ Input }
type Store interface {
	List(context.Context, Request) (Result, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }
func (service Service) List(context context.Context, input Input) (Result, error) {
	return service.store.List(context, Request{Input: input})
}
