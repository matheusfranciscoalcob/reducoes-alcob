# Reduções ALCOB

Aplicação web isolada para leitura OCR de laudos, histórico compartilhado de corridas e análise de redução de elementos químicos.

## Arquitetura

- GitHub Pages: hospedagem estática.
- Supabase Auth: confirmação de e-mail, acesso por senha e aprovação administrativa.
- Supabase Postgres: corridas, amostras e catálogo dinâmico de elementos.
- Supabase Storage: laudos em bucket privado.
- Tesseract.js: OCR executado no navegador.
- Agrupamento operacional: ano/mês + forno + fornada, preservando análises feitas em dias e turnos diferentes.
- Monitoramento especial: códigos no formato `F#.MONITORAMENTO J#` são separados das fornadas e agrupados por forno, jumbo, mês e ano.

O projeto Supabase `reducoes-alcob` é separado do projeto existente `Auditorias Alcob`.

## Segurança

- Uma conta nova começa como solicitação pendente e não acessa dados nem fotos.
- Somente `matheusferfran2010@gmail.com` pode aprovar ou revogar acessos pela interface.
- A aprovação é aplicada no banco por RLS; ocultar a interface não é a única barreira.
- Row Level Security está habilitado em todas as tabelas.
- O bucket `lab-reports` é privado.
- O navegador recebe somente a chave publicável; nenhuma chave secreta é incluída no repositório.

## Banco

As migrações versionadas estão em `supabase/migrations/`. As migrações `20260807173000_access_approval.sql` e `20260807174500_access_approval_hardening.sql` adicionam e reforçam o fluxo de aprovação. A migração `20260807183000_analysis_grouping.sql` estrutura o código de cada análise e cria os índices de forno, fornada e jumbo.

Para enviar confirmações a endereços que não pertencem à equipe do projeto Supabase, configure um servidor SMTP próprio em **Authentication → Email → SMTP Settings**. O SMTP padrão do Supabase é limitado a membros da equipe do projeto.
