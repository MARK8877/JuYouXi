package main

import (
	"context"
	"database/sql"
	"errors"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"juku-library-db/internal/api"
	"juku-library-db/internal/store"
)

func main() {
	addr := flag.String("addr", envOr("JUKU_ADDR", ":9010"), "HTTP listen address")
	schemaPath := flag.String("schema", envOr("JUKU_SCHEMA_FILE", "schema.sql"), "schema SQL file")
	flag.Parse()

	dsn := strings.TrimSpace(os.Getenv("JUKU_MYSQL_DSN"))
	openapiPath := envOr("JUKU_OPENAPI_FILE", "openapi.yaml")
	openapiSpec, err := os.ReadFile(openapiPath)
	if err != nil {
		log.Fatal(fmt.Errorf("read OpenAPI spec %s: %w", openapiPath, err))
	}
	var handler http.Handler
	if !shouldUseMySQL(dsn) {
		log.Printf("JUKU_MYSQL_DSN is not set; starting docs/in-memory mode without persistence")
		handler = api.NewServerWithSpec(store.NewMemory(), openapiSpec)
	} else {
		database, err := sql.Open("mysql", dsn)
		if err != nil {
			log.Fatal(err)
		}
		defer database.Close()
		database.SetMaxOpenConns(10)
		database.SetMaxIdleConns(5)
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		if err := database.PingContext(ctx); err != nil {
			cancel()
			log.Fatal(fmt.Errorf("mysql ping failed: %w", err))
		}
		if err := migrate(ctx, database, *schemaPath); err != nil {
			cancel()
			log.Fatal(err)
		}
		cancel()
		databaseStore := store.NewMySQL(database)
		startEngagementGrowth(context.Background(), databaseStore)
		handler = api.NewServerWithSpec(databaseStore, openapiSpec)
	}

	log.Printf("library API listening on %s", *addr)
	if err := http.ListenAndServe(*addr, handler); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}

func startEngagementGrowth(ctx context.Context, database store.Store) {
	ticker := time.NewTicker(10 * time.Minute)
	go func() {
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case now := <-ticker.C:
				if err := database.AdvanceEngagementGrowth(ctx, now.UTC()); err != nil {
					log.Printf("advance simulated engagement heat: %v", err)
				}
			}
		}
	}()
}

func shouldUseMySQL(dsn string) bool { return strings.TrimSpace(dsn) != "" }

func migrate(ctx context.Context, database *sql.DB, path string) error {
	body, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("read schema %s: %w", path, err)
	}
	for _, statement := range strings.Split(string(body), ";") {
		statement = strings.TrimSpace(statement)
		upper := strings.ToUpper(statement)
		if statement == "" || strings.HasPrefix(upper, "CREATE DATABASE") || strings.HasPrefix(upper, "USE ") {
			continue
		}
		if _, err := database.ExecContext(ctx, statement); err != nil {
			return fmt.Errorf("apply schema statement: %w", err)
		}
	}
	var parentColumnCount int
	if err := database.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM information_schema.columns
		WHERE table_schema=DATABASE() AND table_name='drama_comments' AND column_name='parent_id'`).Scan(&parentColumnCount); err != nil {
		return fmt.Errorf("check drama_comments.parent_id: %w", err)
	}
	if parentColumnCount == 0 {
		if _, err := database.ExecContext(ctx, `ALTER TABLE drama_comments ADD COLUMN parent_id VARCHAR(128) NULL`); err != nil {
			return fmt.Errorf("add drama_comments.parent_id: %w", err)
		}
	}
	return nil
}

func envOr(name, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(name)); value != "" {
		return value
	}
	return fallback
}
