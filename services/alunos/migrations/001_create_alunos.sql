-- Schema dedicado ao microsserviço de Alunos (não compartilhado com outros serviços)
CREATE SCHEMA IF NOT EXISTS alunos;

CREATE TABLE IF NOT EXISTS alunos.alunos (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome       VARCHAR(255) NOT NULL,
    email      VARCHAR(255) NOT NULL,
    matricula  VARCHAR(50)  NOT NULL,
    criado_em  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT alunos_email_unique    UNIQUE (email),
    CONSTRAINT alunos_matricula_unique UNIQUE (matricula)
);
