package main

import (
	"encoding/json"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
)

func TestTransactionLifecycle(t *testing.T) {
	path := filepath.Join(t.TempDir(), "finance.json")
	s, err := openStore(path)
	if err != nil {
		t.Fatal(err)
	}
	call := func(method, path, body string, want int) *httptest.ResponseRecorder {
		t.Helper()
		w := httptest.NewRecorder()
		s.handler().ServeHTTP(w, httptest.NewRequest(method, path, strings.NewReader(body)))
		if w.Code != want {
			t.Fatalf("%s %s: got %d: %s", method, path, w.Code, w.Body.String())
		}
		return w
	}
	call("POST", "/api/transactions", `{"accountId":"missing","categoryId":"1","description":"Food","amount":-1250,"date":"2026-10-18"}`, 400)
	call("POST", "/api/transactions", `{"accountId":"1","categoryId":"1","description":"Food","amount":0,"date":"2026-10-18"}`, 400)
	w := call("POST", "/api/transactions", `{"accountId":"1","categoryId":"1","description":"Food","amount":-1250,"date":"2026-10-18"}`, 201)
	var tx Transaction
	if err = json.Unmarshal(w.Body.Bytes(), &tx); err != nil {
		t.Fatal(err)
	}
	restored, err := openStore(path)
	if err != nil {
		t.Fatal(err)
	}
	if len(restored.data.Transactions) != 1 || restored.data.Transactions[0].Amount != -1250 {
		t.Fatal("transaction did not persist")
	}
	call("DELETE", "/api/transactions/"+tx.ID, "", 204)
	call("DELETE", "/api/transactions/"+tx.ID, "", 404)
	call("POST", "/api/accounts", `{"name":"Savings","opening":50000}`, 201)
	restored, err = openStore(path)
	if err != nil {
		t.Fatal(err)
	}
	if len(restored.data.Transactions) != 0 || len(restored.data.Accounts) != 2 {
		t.Fatal("changes did not persist")
	}
}
