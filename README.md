# Reduções ALCOB

Aplicação web isolada para leitura OCR de laudos, histórico compartilhado de corridas e análise de redução de elementos químicos.

## Arquitetura

- GitHub Pages: hospedagem estática.
- Supabase Auth: acesso por e-mail e senha.
- Supabase Postgres: corridas, amostras e catálogo dinâmico de elementos.
- Supabase Storage: laudos em bucket privado.
- Tesseract.js: OCR executado no navegador.

O projeto Supabase `reducoes-alcob` é separado do projeto existente `Auditorias Alcob`.

## Segurança

- Somente usuários autenticados acessam dados e fotos.
- Row Level Security está habilitado em todas as tabelas.
- O bucket `lab-reports` é privado.
- O navegador recebe somente a chave publicável; nenhuma chave secreta é incluída no repositório.

## Banco

A migração versionada está em `supabase/migrations/20260807153000_initial_schema.sql`.
