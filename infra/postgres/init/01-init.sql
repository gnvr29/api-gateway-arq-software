-- ─── Database and User Setup ───────────────────────────────────────────────
-- This runs on first container boot (fresh volume) as the postgres superuser.
-- Creates isolated databases and users for each service.

-- Alunos service
CREATE USER alunos WITH PASSWORD 'alunos';
CREATE DATABASE alunos_db OWNER alunos;
GRANT ALL PRIVILEGES ON DATABASE alunos_db TO alunos;

-- Cursos service
CREATE USER cursos WITH PASSWORD 'cursos';
CREATE DATABASE cursos_db OWNER cursos;
GRANT ALL PRIVILEGES ON DATABASE cursos_db TO cursos;
