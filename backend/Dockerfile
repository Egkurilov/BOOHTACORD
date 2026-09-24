FROM golang:1.26.4-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY cmd ./cmd
COPY internal ./internal
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/api ./cmd/api
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/migrate ./cmd/migrate
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/bootstrap-admin ./cmd/bootstrap_admin
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/recover-admin ./cmd/recover_admin
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/recover-last-admin-access ./cmd/recover_last_admin_access
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/maintenance-admission ./cmd/maintenance_admission
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/cleanup-stale-staging ./cmd/cleanup_stale_staging
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/cleanup-unattached-attachments ./cmd/cleanup_unattached_attachments
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/cleanup-hidden-attachments ./cmd/cleanup_hidden_attachments

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/api /api
COPY --from=build /out/migrate /migrate
COPY --from=build /out/bootstrap-admin /bootstrap-admin
COPY --from=build /out/recover-admin /recover-admin
COPY --from=build /out/recover-last-admin-access /recover-last-admin-access
COPY --from=build /out/maintenance-admission /maintenance-admission
COPY --from=build /out/cleanup-stale-staging /cleanup-stale-staging
COPY --from=build /out/cleanup-unattached-attachments /cleanup-unattached-attachments
COPY --from=build /out/cleanup-hidden-attachments /cleanup-hidden-attachments
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/api"]
