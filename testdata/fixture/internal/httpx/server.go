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
