package mozlog // import "go.mozilla.org/mozlog"

import (
	"bytes"
	"encoding/json"
	"log"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestMozLogger(t *testing.T) {
	log.SetFlags(0)

	in := new(bytes.Buffer)
	Logger.Output = in

	log.Println("test message")

	var logEntry AppLog
	err := json.Unmarshal(in.Bytes(), &logEntry)
	assert.NoError(t, err)

	assert.Equal(t, "test message", logEntry.Fields["msg"])
}

func TestJSONLogger(t *testing.T) {
	log.SetFlags(0)

	in := new(bytes.Buffer)
	Logger.Output = in

	log.Println(`{"a": 1234, "b": true, "c": [1, 2]}`)

	var logEntry AppLog
	err := json.Unmarshal(in.Bytes(), &logEntry)
	assert.NoError(t, err)
	lefields, err := json.Marshal(logEntry.Fields)
	assert.NoError(t, err)
	assert.JSONEq(t, `{"b": true, "c": [1, 2], "a": 1234}`, string(lefields))
}
