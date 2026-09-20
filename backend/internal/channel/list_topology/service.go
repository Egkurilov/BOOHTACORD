package listtopology

import "context"

type Channel struct {
	ID, Name        string
	Kind            string
	Position        int
	AdmissionClosed bool
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
type Store interface {
	List(context.Context) (Result, error)
}
type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }
func (service Service) List(context context.Context) (Result, error) {
	return service.store.List(context)
}
