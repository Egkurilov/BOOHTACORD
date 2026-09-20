package writeupload

import (
	"context"
	"io"
)

type Guard func(context.Context) error

func (writer Writer) WriteGuarded(ctx context.Context, source io.Reader, guard Guard) (Result, error) {
	return writer.write(ctx, source, guard)
}

type contextReader struct {
	ctx    context.Context
	source io.Reader
	guard  Guard
}

func (reader contextReader) Read(buffer []byte) (int, error) {
	if err := reader.ctx.Err(); err != nil {
		return 0, err
	}
	if reader.guard != nil {
		if err := reader.guard(reader.ctx); err != nil {
			return 0, err
		}
	}
	return reader.source.Read(buffer)
}
