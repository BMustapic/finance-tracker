package main

import (
	"crypto/rand"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

type Account struct {
	ID      string `json:"id"`
	Name    string `json:"name"`
	Opening int64  `json:"opening"`
}
type Category struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}
type Transaction struct {
	ID          string `json:"id"`
	AccountID   string `json:"accountId"`
	CategoryID  string `json:"categoryId"`
	Description string `json:"description"`
	Amount      int64  `json:"amount"`
	Date        string `json:"date"`
}
type Data struct {
	Accounts     []Account     `json:"accounts"`
	Categories   []Category    `json:"categories"`
	Transactions []Transaction `json:"transactions"`
}
type Store struct {
	mu   sync.Mutex
	path string
	data Data
}

func openStore(path string) (*Store, error) {
	s := &Store{path: path, data: Data{Accounts: []Account{{"1", "Everyday account", 0}}, Categories: []Category{{"1", "Groceries"}, {"2", "Transport"}, {"3", "Home"}, {"4", "Entertainment"}, {"5", "Salary"}, {"6", "Other"}}, Transactions: []Transaction{}}}
	b, err := os.ReadFile(path)
	if err == nil {
		err = json.Unmarshal(b, &s.data)
	} else if errors.Is(err, os.ErrNotExist) {
		err = s.save(s.data)
	}
	return s, err
}
func (s *Store) save(d Data) error {
	if err := os.MkdirAll(filepath.Dir(s.path), 0700); err != nil {
		return err
	}
	b, err := json.MarshalIndent(d, "", "  ")
	if err != nil {
		return err
	}
	if err = os.WriteFile(s.path+".tmp", b, 0600); err != nil {
		return err
	}
	return os.Rename(s.path+".tmp", s.path)
}
func reply(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
func fail(w http.ResponseWriter, status int, message string) {
	reply(w, status, map[string]string{"error": message})
}
func decode(w http.ResponseWriter, r *http.Request, v any) bool {
	r.Body = http.MaxBytesReader(w, r.Body, 4096)
	d := json.NewDecoder(r.Body)
	d.DisallowUnknownFields()
	if err := d.Decode(v); err != nil {
		fail(w, 400, "Invalid JSON request")
		return false
	}
	return true
}
func id() string { return rand.Text() }
func (s *Store) handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/health", func(w http.ResponseWriter, r *http.Request) { reply(w, 200, map[string]string{"status": "ok"}) })
	mux.HandleFunc("GET /api/data", func(w http.ResponseWriter, r *http.Request) { s.mu.Lock(); defer s.mu.Unlock(); reply(w, 200, s.data) })
	mux.HandleFunc("POST /api/accounts", func(w http.ResponseWriter, r *http.Request) {
		var a Account
		if !decode(w, r, &a) {
			return
		}
		a.Name = strings.TrimSpace(a.Name)
		if len(a.Name) == 0 || len(a.Name) > 80 || a.Opening > 100000000000 || a.Opening < -100000000000 {
			fail(w, 400, "Provide a name (1–80 characters) and a valid opening balance in cents")
			return
		}
		a.ID = id()
		s.mu.Lock()
		defer s.mu.Unlock()
		d := s.data
		d.Accounts = append(append([]Account{}, d.Accounts...), a)
		if err := s.save(d); err != nil {
			fail(w, 500, "Could not save account")
			return
		}
		s.data = d
		reply(w, 201, a)
	})
	mux.HandleFunc("POST /api/transactions", func(w http.ResponseWriter, r *http.Request) {
		var t Transaction
		if !decode(w, r, &t) {
			return
		}
		t.Description = strings.TrimSpace(t.Description)
		_, dateErr := time.Parse("2006-01-02", t.Date)
		if dateErr != nil || t.Amount == 0 || t.Amount > 100000000000 || t.Amount < -100000000000 || len(t.Description) == 0 || len(t.Description) > 160 {
			fail(w, 400, "Provide a valid date, description, and nonzero amount in cents")
			return
		}
		s.mu.Lock()
		defer s.mu.Unlock()
		account, category := false, false
		for _, a := range s.data.Accounts {
			if a.ID == t.AccountID {
				account = true
			}
		}
		for _, c := range s.data.Categories {
			if c.ID == t.CategoryID {
				category = true
			}
		}
		if !account || !category {
			fail(w, 400, "Unknown account or category")
			return
		}
		t.ID = id()
		d := s.data
		d.Transactions = append(append([]Transaction{}, d.Transactions...), t)
		if err := s.save(d); err != nil {
			fail(w, 500, "Could not save transaction")
			return
		}
		s.data = d
		reply(w, 201, t)
	})
	mux.HandleFunc("DELETE /api/transactions/{id}", func(w http.ResponseWriter, r *http.Request) {
		s.mu.Lock()
		defer s.mu.Unlock()
		d := s.data
		d.Transactions = []Transaction{}
		found := false
		for _, t := range s.data.Transactions {
			if t.ID == r.PathValue("id") {
				found = true
			} else {
				d.Transactions = append(d.Transactions, t)
			}
		}
		if !found {
			fail(w, 404, "Transaction not found")
			return
		}
		if err := s.save(d); err != nil {
			fail(w, 500, "Could not delete transaction")
			return
		}
		s.data = d
		w.WriteHeader(204)
	})
	return mux
}
func main() {
	path := os.Getenv("DATA_FILE")
	if path == "" {
		path = "data/finance.json"
	}
	s, err := openStore(path)
	if err != nil {
		log.Fatal(err)
	}
	addr := os.Getenv("LISTEN_ADDR")
	if addr == "" {
		addr = "127.0.0.1:8080"
	}
	log.Printf("Finance API listening on %s", addr)
	server := &http.Server{Addr: addr, Handler: s.handler(), ReadHeaderTimeout: 5 * time.Second}
	log.Fatal(server.ListenAndServe())
}
