-- Schema dedicado ao microsserviço de Cursos (não compartilhado com outros serviços)
CREATE SCHEMA IF NOT EXISTS cursos;

CREATE TABLE IF NOT EXISTS cursos.cursos (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome          VARCHAR(255) NOT NULL,
    descricao     TEXT NOT NULL DEFAULT '',
    carga_horaria INTEGER NOT NULL DEFAULT 0,
    criado_em     TIMESTAMPTZ NOT NULL DEFAULT now()
);
