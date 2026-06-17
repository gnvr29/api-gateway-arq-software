package handler

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strings"

	"github.com/google/uuid"

	"github.com/gnvr29/api-gateway-arq-software/services/alunos/internal/model"
	"github.com/gnvr29/api-gateway-arq-software/services/alunos/internal/repository"
)

// AlunosHandler concentra os handlers HTTP do recurso /alunos.
type AlunosHandler struct {
	repo   *repository.AlunosRepository
	logger *slog.Logger
}

func NewAlunosHandler(repo *repository.AlunosRepository, logger *slog.Logger) *AlunosHandler {
	return &AlunosHandler{repo: repo, logger: logger}
}

type createAlunoRequest struct {
	Nome      string `json:"nome"`
	Email     string `json:"email"`
	Matricula string `json:"matricula"`
}

// Create cadastra um novo aluno. POST /alunos
func (h *AlunosHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req createAlunoRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "corpo da requisição inválido")
		return
	}

	req.Nome = strings.TrimSpace(req.Nome)
	req.Email = strings.TrimSpace(req.Email)
	req.Matricula = strings.TrimSpace(req.Matricula)

	if req.Nome == "" {
		respondError(w, http.StatusBadRequest, "o campo 'nome' é obrigatório")
		return
	}
	if req.Email == "" {
		respondError(w, http.StatusBadRequest, "o campo 'email' é obrigatório")
		return
	}
	if req.Matricula == "" {
		respondError(w, http.StatusBadRequest, "o campo 'matricula' é obrigatório")
		return
	}

	aluno := &model.Aluno{
		Nome:      req.Nome,
		Email:     req.Email,
		Matricula: req.Matricula,
	}

	if err := h.repo.Create(r.Context(), aluno); err != nil {
		if errors.Is(err, repository.ErrDuplicado) {
			respondError(w, http.StatusConflict, "email ou matrícula já cadastrado")
			return
		}
		h.logger.Error("falha ao cadastrar aluno", "error", err)
		respondError(w, http.StatusServiceUnavailable, "banco de dados indisponível")
		return
	}

	respondJSON(w, http.StatusCreated, aluno)
}

// List retorna todos os alunos cadastrados. GET /alunos
func (h *AlunosHandler) List(w http.ResponseWriter, r *http.Request) {
	alunos, err := h.repo.FindAll(r.Context())
	if err != nil {
		h.logger.Error("falha ao listar alunos", "error", err)
		respondError(w, http.StatusServiceUnavailable, "banco de dados indisponível")
		return
	}

	respondJSON(w, http.StatusOK, alunos)
}

// GetByID busca um aluno pelo ID. GET /alunos/{id}
func (h *AlunosHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")

	if _, err := uuid.Parse(id); err != nil {
		respondError(w, http.StatusNotFound, "aluno não encontrado")
		return
	}

	aluno, err := h.repo.FindByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, repository.ErrAlunoNotFound) {
			respondError(w, http.StatusNotFound, "aluno não encontrado")
			return
		}
		h.logger.Error("falha ao buscar aluno", "error", err, "id", id)
		respondError(w, http.StatusServiceUnavailable, "banco de dados indisponível")
		return
	}

	respondJSON(w, http.StatusOK, aluno)
}

// Health responde ao health check do serviço. GET /health
func Health(w http.ResponseWriter, r *http.Request) {
	respondJSON(w, http.StatusOK, map[string]string{
		"status":  "ok",
		"service": "alunos",
	})
}

func respondJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func respondError(w http.ResponseWriter, status int, message string) {
	respondJSON(w, status, map[string]string{"error": message})
}
