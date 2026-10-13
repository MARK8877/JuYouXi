package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"juku-library-db/internal/store"
)

func main() {
	filePath := flag.String("file", "", "JSON file containing a Drama array or {\"data\": [...]}")
	flag.Parse()
	if strings.TrimSpace(*filePath) == "" {
		log.Fatal("-file is required")
	}
	dsn := strings.TrimSpace(os.Getenv("JUKU_MYSQL_DSN"))
	if dsn == "" {
		log.Fatal("JUKU_MYSQL_DSN is required; it is not written to project files")
	}
	body, err := os.ReadFile(*filePath)
	if err != nil {
		log.Fatal(err)
	}
	dramas, err := decodeDramas(body)
	if err != nil {
		log.Fatal(err)
	}
	database, err := sql.Open("mysql", dsn)
	if err != nil {
		log.Fatal(err)
	}
	defer database.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err := database.PingContext(ctx); err != nil {
		log.Fatal(err)
	}
	databaseStore := store.NewMySQL(database)
	for _, drama := range dramas {
		if err := databaseStore.UpsertDrama(ctx, drama); err != nil {
			log.Fatalf("import %s: %v", drama.ID, err)
		}
	}
	log.Printf("imported %d dramas", len(dramas))
}

func decodeDramas(body []byte) ([]store.Drama, error) {
	var dramas []store.Drama
	if err := json.Unmarshal(body, &dramas); err == nil {
		return dramas, nil
	}
	var envelope struct {
		Data []store.Drama `json:"data"`
	}
	if err := json.Unmarshal(body, &envelope); err != nil || envelope.Data == nil {
		if err == nil {
			err = errors.New("JSON must be a Drama array or an object with data")
		}
		return nil, fmt.Errorf("decode dramas: %w", err)
	}
	return envelope.Data, nil
}
