package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"

	"github.com/gnvr29/api-gateway-arq-software/services/alunos/internal/model"
)

// ErrAlunoNotFound é retornado quando nenhum aluno é encontrado para o ID informado.
var ErrAlunoNotFound = errors.New("aluno não encontrado")

// ErrDuplicado é retornado quando email ou matrícula já existem no banco.
var ErrDuplicado = errors.New("email ou matrícula já cadastrado")

// AlunosRepository encapsula o acesso à tabela alunos.alunos.
type AlunosRepository struct {
	db *sql.DB
}

func NewAlunosRepository(db *sql.DB) *AlunosRepository {
	return &AlunosRepository{db: db}
}

// Create insere um novo aluno e preenche o ID e CriadoEm gerados pelo banco.
func (r *AlunosRepository) Create(ctx context.Context, aluno *model.Aluno) error {
	const query = `
		INSERT INTO alunos.alunos (nome, email, matricula)
		VALUES ($1, $2, $3)
		RETURNING id, criado_em`

	err := r.db.QueryRowContext(ctx, query, aluno.Nome, aluno.Email, aluno.Matricula).
		Scan(&aluno.ID, &aluno.CriadoEm)
	if err != nil {
		if isUniqueViolation(err) {
			return ErrDuplicado
		}
		return fmt.Errorf("inserindo aluno: %w", err)
	}

	return nil
}

// FindAll retorna todos os alunos cadastrados, do mais recente para o mais antigo.
func (r *AlunosRepository) FindAll(ctx context.Context) ([]model.Aluno, error) {
	const query = `
		SELECT id, nome, email, matricula, criado_em
		FROM alunos.alunos
		ORDER BY criado_em DESC`

	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("consultando alunos: %w", err)
	}
	defer rows.Close()

	alunos := []model.Aluno{}
	for rows.Next() {
		var a model.Aluno
		if err := rows.Scan(&a.ID, &a.Nome, &a.Email, &a.Matricula, &a.CriadoEm); err != nil {
			return nil, fmt.Errorf("lendo aluno: %w", err)
		}
		alunos = append(alunos, a)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterando alunos: %w", err)
	}

	return alunos, nil
}

// FindByID busca um aluno pelo seu ID. Retorna ErrAlunoNotFound se não existir.
func (r *AlunosRepository) FindByID(ctx context.Context, id string) (*model.Aluno, error) {
	const query = `
		SELECT id, nome, email, matricula, criado_em
		FROM alunos.alunos
		WHERE id = $1`

	var aluno model.Aluno
	err := r.db.QueryRowContext(ctx, query, id).
		Scan(&aluno.ID, &aluno.Nome, &aluno.Email, &aluno.Matricula, &aluno.CriadoEm)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrAlunoNotFound
		}
		return nil, fmt.Errorf("consultando aluno %s: %w", id, err)
	}

	return &aluno, nil
}

// isUniqueViolation detecta violação de constraint UNIQUE do PostgreSQL (código SQLSTATE 23505).
func isUniqueViolation(err error) bool {
	return strings.Contains(err.Error(), "23505") || strings.Contains(err.Error(), "unique")
}
