package main

import (
	"encoding/json"
	"log"
	"net/http"
)

type accessLog struct {
	Type          string `json:"type"`
	XForwardedFor string `json:"x-forwarded-for"`
	Method        string `json:"method"`
	Proto         string `json:"proto"`
	URL           string `json:"url"`
	UserAgent     string `json:"user-agent"`
	RequestID     string `json:"rid"`
}

func (al *accessLog) String() string {
	al.Type = "request"
	msg, _ := json.Marshal(al)
	return string(msg)
}

type appLog struct {
	Type      string `json:"type"`
	RequestID string `json:"rid"`
	Message   string `json:"msg"`
	ErrorCode int    `json:"error-code"`
	User      string `json:"user,omitempty"`
	Action    string `json:"action,omitempty"`
}

func (al *appLog) String() string {
	msg, _ := json.Marshal(al)
	return string(msg)
}

func (al *appLog) log(r *http.Request) {
	al.Type = "action"
	val := r.Context().Value(ctxReqID)
	if val != nil {
		al.RequestID = val.(string)
	}
	log.Printf("%s", al.String())
}
