package handler

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strings"

	"github.com/google/uuid"

	"github.com/gnvr29/api-gateway-arq-software/services/cursos/internal/model"
	"github.com/gnvr29/api-gateway-arq-software/services/cursos/internal/repository"
)

// CursosHandler concentra os handlers HTTP do recurso /cursos.
type CursosHandler struct {
	repo   *repository.CursosRepository
	logger *slog.Logger
}

func NewCursosHandler(repo *repository.CursosRepository, logger *slog.Logger) *CursosHandler {
	return &CursosHandler{repo: repo, logger: logger}
}

type createCursoRequest struct {
	Nome         string `json:"nome"`
	Descricao    string `json:"descricao"`
	CargaHoraria int    `json:"carga_horaria"`
}

// Create cadastra um novo curso. POST /cursos
func (h *CursosHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req createCursoRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "corpo da requisição inválido")
		return
	}

	req.Nome = strings.TrimSpace(req.Nome)
	if req.Nome == "" {
		respondError(w, http.StatusBadRequest, "o campo 'nome' é obrigatório")
		return
	}
	if req.CargaHoraria < 0 {
		respondError(w, http.StatusBadRequest, "o campo 'carga_horaria' não pode ser negativo")
		return
	}

	curso := &model.Curso{
		Nome:         req.Nome,
		Descricao:    req.Descricao,
		CargaHoraria: req.CargaHoraria,
	}

	if err := h.repo.Create(r.Context(), curso); err != nil {
		h.logger.Error("falha ao cadastrar curso", "error", err)
		respondError(w, http.StatusInternalServerError, "erro ao cadastrar curso")
		return
	}

	respondJSON(w, http.StatusCreated, curso)
}

// List retorna todos os cursos cadastrados. GET /cursos
func (h *CursosHandler) List(w http.ResponseWriter, r *http.Request) {
	cursos, err := h.repo.FindAll(r.Context())
	if err != nil {
		h.logger.Error("falha ao listar cursos", "error", err)
		respondError(w, http.StatusInternalServerError, "erro ao listar cursos")
		return
	}

	respondJSON(w, http.StatusOK, cursos)
}

// GetByID busca um curso pelo ID. GET /cursos/{id}
func (h *CursosHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")

	if _, err := uuid.Parse(id); err != nil {
		respondError(w, http.StatusNotFound, "curso não encontrado")
		return
	}

	curso, err := h.repo.FindByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, repository.ErrCursoNotFound) {
			respondError(w, http.StatusNotFound, "curso não encontrado")
			return
		}
		h.logger.Error("falha ao buscar curso", "error", err, "id", id)
		respondError(w, http.StatusInternalServerError, "erro ao buscar curso")
		return
	}

	respondJSON(w, http.StatusOK, curso)
}

// Health responde ao health check do serviço. GET /health
func Health(w http.ResponseWriter, r *http.Request) {
	respondJSON(w, http.StatusOK, map[string]string{
		"status":  "ok",
		"service": "cursos",
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
