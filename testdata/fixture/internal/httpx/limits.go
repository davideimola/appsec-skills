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
