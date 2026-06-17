package model

import "time"

// Aluno representa um aluno cadastrado na instituição.
type Aluno struct {
	ID        string    `json:"id"`
	Nome      string    `json:"nome"`
	Email     string    `json:"email"`
	Matricula string    `json:"matricula"`
	CriadoEm time.Time `json:"criado_em"`
}
