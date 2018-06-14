package main

import (
	"context"
	"log"
	"net/http"
)

// Middleware wraps an http.Handler with additional
// functionality.
type Middleware func(http.Handler) http.Handler

const (
	ctxReqID = "reqID"
)

func logRequest() Middleware {
	return func(h http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			h.ServeHTTP(w, r)
			al := accessLog{
				XForwardedFor: r.Header.Get("X-Forwarded-For"),
				Method:        r.Method,
				Proto:         r.Proto,
				URL:           r.URL.String(),
				UserAgent:     r.UserAgent(),
				RequestID:     "-",
			}
			val := r.Context().Value(ctxReqID)
			if val != nil {
				al.RequestID = val.(string)
			}
			log.Printf("%s", al.String())
		})
	}
}

func setResponseHeaders() Middleware {
	return func(h http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			/* These will be set in chapter 3
			 *
			w.Header().Add("Content-Security-Policy", "default-src 'self'; child-src 'self;")
			w.Header().Add("X-XSS-Protection", "1; mode=block")
			w.Header().Add("X-Frame-Options", "SAMEORIGIN")
			w.Header().Add("X-Content-Type-Options", "nosniff")
			w.Header().Add("Strict-Transport-Security", "max-age=31536000;")
			w.Header().Add("Public-Key-Pins", `max-age=1296000; pin-sha256="YLh1dUR9y6Kja30RrAn7JKnbQG/uEtLMkBgFF2Fuihg="; pin-sha256="++MBgDH5WGvL9Bcn5Be30cRcL0f5O+NyoXuWtQdX1aI="`)
			*/
			h.ServeHTTP(w, r)
		})
	}
}

func addRequestID() Middleware {
	return func(h http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			rid := newRequestID()
			h.ServeHTTP(w, addtoContext(r, ctxReqID, rid))
		})
	}
}

//  Run the request through all middlewares
func HandleMiddlewares(h http.Handler, adapters ...Middleware) http.Handler {
	// To make the middleware run in the order in which they are specified,
	// we reverse through them in the Middleware function, rather than just
	// ranging over them
	for i := len(adapters) - 1; i >= 0; i-- {
		h = adapters[i](h)
	}
	return h
}

// addToContext add the given key value pair to the given request's context
func addtoContext(r *http.Request, key string, value interface{}) *http.Request {
	ctx := r.Context()
	return r.WithContext(context.WithValue(ctx, key, value))
}
