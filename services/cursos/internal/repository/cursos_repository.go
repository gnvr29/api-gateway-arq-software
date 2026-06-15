package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/gnvr29/api-gateway-arq-software/services/cursos/internal/model"
)

// ErrCursoNotFound é retornado quando nenhum curso é encontrado para o ID informado.
var ErrCursoNotFound = errors.New("curso não encontrado")

// CursosRepository encapsula o acesso à tabela cursos.cursos.
type CursosRepository struct {
	db *sql.DB
}

func NewCursosRepository(db *sql.DB) *CursosRepository {
	return &CursosRepository{db: db}
}

// Create insere um novo curso e preenche o ID e CriadoEm gerados pelo banco.
func (r *CursosRepository) Create(ctx context.Context, curso *model.Curso) error {
	const query = `
		INSERT INTO cursos.cursos (nome, descricao, carga_horaria)
		VALUES ($1, $2, $3)
		RETURNING id, criado_em`

	err := r.db.QueryRowContext(ctx, query, curso.Nome, curso.Descricao, curso.CargaHoraria).
		Scan(&curso.ID, &curso.CriadoEm)
	if err != nil {
		return fmt.Errorf("inserindo curso: %w", err)
	}

	return nil
}

// FindAll retorna todos os cursos cadastrados, do mais recente para o mais antigo.
func (r *CursosRepository) FindAll(ctx context.Context) ([]model.Curso, error) {
	const query = `
		SELECT id, nome, descricao, carga_horaria, criado_em
		FROM cursos.cursos
		ORDER BY criado_em DESC`

	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("consultando cursos: %w", err)
	}
	defer rows.Close()

	cursos := []model.Curso{}
	for rows.Next() {
		var curso model.Curso
		if err := rows.Scan(&curso.ID, &curso.Nome, &curso.Descricao, &curso.CargaHoraria, &curso.CriadoEm); err != nil {
			return nil, fmt.Errorf("lendo curso: %w", err)
		}
		cursos = append(cursos, curso)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterando cursos: %w", err)
	}

	return cursos, nil
}

// FindByID busca um curso pelo seu ID. Retorna ErrCursoNotFound se não existir.
func (r *CursosRepository) FindByID(ctx context.Context, id string) (*model.Curso, error) {
	const query = `
		SELECT id, nome, descricao, carga_horaria, criado_em
		FROM cursos.cursos
		WHERE id = $1`

	var curso model.Curso
	err := r.db.QueryRowContext(ctx, query, id).
		Scan(&curso.ID, &curso.Nome, &curso.Descricao, &curso.CargaHoraria, &curso.CriadoEm)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrCursoNotFound
		}
		return nil, fmt.Errorf("consultando curso %s: %w", id, err)
	}

	return &curso, nil
}
