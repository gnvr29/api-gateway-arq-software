package main

import (
	"embed"
	"log/slog"
	"net/http"
	"os"
	"time"

	"github.com/gnvr29/api-gateway-arq-software/services/alunos/internal/database"
	"github.com/gnvr29/api-gateway-arq-software/services/alunos/internal/handler"
	"github.com/gnvr29/api-gateway-arq-software/services/alunos/internal/middleware"
	"github.com/gnvr29/api-gateway-arq-software/services/alunos/internal/repository"
)

//go:embed migrations/*.sql
var migrationsFS embed.FS

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	db, err := database.Connect()
	if err != nil {
		logger.Error("falha ao conectar ao banco de dados", "error", err)
		os.Exit(1)
	}
	defer db.Close()

	if err := database.Migrate(db, migrationsFS); err != nil {
		logger.Error("falha ao executar migrations", "error", err)
		os.Exit(1)
	}

	repo := repository.NewAlunosRepository(db)
	alunosHandler := handler.NewAlunosHandler(repo, logger)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", handler.Health)
	mux.HandleFunc("POST /alunos", alunosHandler.Create)
	mux.HandleFunc("GET /alunos", alunosHandler.List)
	mux.HandleFunc("GET /alunos/{id}", alunosHandler.GetByID)

	var handlerChain http.Handler = mux
	handlerChain = middleware.Logging(logger)(handlerChain)
	handlerChain = middleware.CORS(handlerChain)

	port := database.GetEnv("PORT", "8081")

	srv := &http.Server{
		Addr:         ":" + port,
		Handler:      handlerChain,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	logger.Info("alunos service iniciado", "port", port)
	if err := srv.ListenAndServe(); err != nil {
		logger.Error("erro no servidor", "error", err)
		os.Exit(1)
	}
}
