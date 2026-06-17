package database

import (
	"database/sql"
	"embed"
	"fmt"
	"os"
	"time"

	_ "github.com/lib/pq"
)

// Connect abre a conexão com o PostgreSQL a partir das variáveis de
// ambiente (com valores default para desenvolvimento local) e aguarda
// o banco ficar disponível antes de retornar.
func Connect() (*sql.DB, error) {
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		GetEnv("DB_HOST", "localhost"),
		GetEnv("DB_PORT", "5432"),
		GetEnv("DB_USER", "alunos"),
		GetEnv("DB_PASSWORD", "alunos"),
		GetEnv("DB_NAME", "alunos_db"),
	)

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, fmt.Errorf("abrindo conexão com o banco: %w", err)
	}

	var lastErr error
	for i := 0; i < 10; i++ {
		if lastErr = db.Ping(); lastErr == nil {
			return db, nil
		}
		time.Sleep(2 * time.Second)
	}

	return nil, fmt.Errorf("banco de dados indisponível: %w", lastErr)
}

// Migrate executa, em ordem, todos os arquivos .sql embarcados em migrationsFS.
// As migrations devem ser idempotentes (CREATE ... IF NOT EXISTS).
func Migrate(db *sql.DB, migrationsFS embed.FS) error {
	entries, err := migrationsFS.ReadDir("migrations")
	if err != nil {
		return fmt.Errorf("lendo diretório de migrations: %w", err)
	}

	for _, entry := range entries {
		content, err := migrationsFS.ReadFile("migrations/" + entry.Name())
		if err != nil {
			return fmt.Errorf("lendo migration %s: %w", entry.Name(), err)
		}

		if _, err := db.Exec(string(content)); err != nil {
			return fmt.Errorf("executando migration %s: %w", entry.Name(), err)
		}
	}

	return nil
}

// GetEnv retorna o valor da variável de ambiente ou um fallback caso ela
// não esteja definida (ou esteja vazia).
func GetEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
