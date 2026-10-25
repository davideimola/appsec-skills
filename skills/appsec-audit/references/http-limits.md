# HTTP limits: server timeouts and request body size

How to find an HTTP server that waits on a client forever, or a handler that reads a request body of any size, and the mechanical fix for each. The fixes are the fixture's `httpx` package, quoted byte for byte: this repo's CI runs its tests.

## Servers without timeouts

The zero-value `http.Server` has no timeouts, so one slow client holds a connection, its goroutine and its buffers for as long as it likes.

Look for:

- `http.ListenAndServe(`, `http.ListenAndServeTLS(`, `http.Serve(` and `http.ServeTLS(`: each runs a zero-value server, which never has timeouts.
- An `http.Server{` literal, or a server whose fields are set after it is built, that leaves `ReadHeaderTimeout` unset or zero (a `ReadTimeout` covers it when `ReadHeaderTimeout` is unset). Other unset timeouts (`ReadTimeout`, `WriteTimeout`, `IdleTimeout`) are part of the same finding.

Evidence: the `file:line` of the call or the literal, and the timeout fields it leaves unset.

Fix (mechanical): build the server with every timeout set, as `NewServer` does, keeping the repo's address and handler. When the repo already has a constructor like this one, use it. A handler that streams, or runs longer than `WriteTimeout`, keeps the server-wide value and extends its own deadline with `http.NewResponseController(w).SetWriteDeadline`.

<!-- fixture: internal/httpx/server.go -->
```go
// Package httpx holds HTTP defaults that are safe for production.
package httpx

import (
	"net/http"
	"time"
)

// NewServer returns an http.Server with every timeout set. The zero-value
// server has none, so one slow client can hold a connection forever.
func NewServer(addr string, h http.Handler) *http.Server {
	return &http.Server{
		Addr:              addr,
		Handler:           h,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       120 * time.Second,
		MaxHeaderBytes:    1 << 20,
	}
}
```

## Request bodies without a size limit

A handler that reads `r.Body` with no limit buffers whatever the client sends. `http.Server` does not limit bodies: `MaxHeaderBytes` covers headers only.

Look for a handler that reads the body (`io.ReadAll(r.Body)`, `json.NewDecoder(r.Body)`, `r.ParseForm()`, `r.ParseMultipartForm(`, `r.FormValue(`) when no `http.MaxBytesReader` wraps `r.Body` on the way there: neither in the handler nor in a middleware that every route to it passes through. Follow the handler's registration up to the server's root handler to check the middleware.

Evidence: the `file:line` where the body is read, and the registration path that shows no limit on it.

Fix (mechanical): wrap the root handler once, for every route, with `MaxBodyBytes` at `DefaultMaxBodyBytes`. A route that takes uploads gets its own larger limit around its handler. A read past the limit returns an error that `errors.As(err, new(*http.MaxBytesError))` recognizes, so the handler can answer `413 Request Entity Too Large`.

<!-- fixture: internal/httpx/limits.go -->
```go
package httpx

import "net/http"

// DefaultMaxBodyBytes caps request bodies at 1 MB.
const DefaultMaxBodyBytes = 1 << 20

// MaxBodyBytes limits every request body to n bytes. Reads past the limit
// fail and the server answers 413 instead of buffering whatever the client
// sends.
func MaxBodyBytes(n int64, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		r.Body = http.MaxBytesReader(w, r.Body, n)
		next.ServeHTTP(w, r)
	})
}
```

When the repo has no such helper, add the function where its HTTP code lives, with its own package name, and use it the same way.
