package model

import "time"

// Curso representa um curso oferecido pela instituição.
type Curso struct {
	ID           string    `json:"id"`
	Nome         string    `json:"nome"`
	Descricao    string    `json:"descricao"`
	CargaHoraria int       `json:"carga_horaria"`
	CriadoEm     time.Time `json:"criado_em"`
}
