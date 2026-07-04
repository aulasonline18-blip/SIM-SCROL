# SIM Scroll — Prova de funcionamento do onboarding

Data: 2026-07-04  
Repositório: `/root/SIM-SCROL`  
Escopo: fluxo inicial do aluno até primeira aula.

## Referências obrigatórias usadas

1. SIM Web — `/root/sim-work/sim-web/src/cyber/useRequireAuth.ts:85-99`  
   O Web tenta `supabase.auth.refreshSession()` quando há sessão armazenada antes de concluir que o usuário está fora.

2. SIM Web — `/root/sim-work/sim-web/src/routes/cyber.curriculo.tsx:57-104`  
   A tela de currículo só prepara a aula quando `authReady && authed`; erro fica na tela com retry, sem jogar o aluno para fora indevidamente.

3. SIM Web — `/root/sim-work/sim-web/src/cyber/curriculo/bootstrapStreamClient.ts:135-140`  
   A chamada para `/api/bootstrap-t00` envia `Authorization: Bearer <token>` quando existe sessão.

4. Supabase — `refreshSession`  
   Referência oficial: https://supabase.com/docs/reference/javascript/auth-refreshsession. A operação é a forma suportada de obter sessão/token renovado.

5. Flutter i18n  
   Referência oficial: https://docs.flutter.dev/ui/internationalization. Texto visível deve responder ao idioma ativo do app.

## Correções realizadas

### 1. Token novo antes do T00 protegido

Arquivo: `lib/features/session/lab_session.dart`

O onboarding real agora chama `_ensureProtectedServerSession(forceRefresh: true)` antes de preparar a aula via T00. Isso reduz o caso do APK manter `authed=true`, mas enviar ao servidor um JWT antigo ou rejeitado.

### 2. Retry único para erro de auth no preparo

Arquivo: `lib/features/session/lab_session.dart`

Se a primeira tentativa de `prepareStudentExperienceEntry` retornar `StudentExperienceErrorKind.auth`, o app faz uma única renovação de sessão e tenta T00 novamente. Se a segunda tentativa falhar, mantém o erro na tela de currículo com retry, como no SIM Web.

### 3. Botão de retry em português

Arquivo: `lib/sim/ui/sim_i18n.dart`

A chave `aula_try_again_2` foi adicionada ao mapa português. A tela da foto deixa de cair no fallback inglês `Try again` e passa a mostrar `Tentar novamente`.

## Provas automatizadas

Arquivo: `test/session_regression_test.dart`

1. `preparacao real sem sessao nao chama servidor protegido e manda para login`  
   Prova que, sem sessão real, o app não chama T00 protegido e manda para login com retorno correto.

2. `erro de auth vindo do preparo fica no curriculo com retry como SimWeb`  
   Prova que erro 401 persistente não desloga nem navega para lugar errado; fica em `/cyber/curriculo` com retry.

3. `onboarding renova auth logicamente e repete T00 uma vez quando servidor devolve 401`  
   Prova o caso da foto: primeira tentativa recebe `HTTP 401 invalid token`; segunda tentativa abre `/cyber/aula`.

4. `erro do onboarding respeita idioma portugues nos botoes de retry`  
   Prova que a tela de erro em português mostra `Não consegui preparar agora.`, `Tentar novamente`, `Trocar objetivo`, e não mostra `Try again`.

5. `curriculo copia SimWeb e espera authReady/authed antes de chamar T00`  
   Prova que a tela de currículo não chama T00 antes de auth pronto/authed.

Arquivo: `test/widget_test.dart`

6. `Objetivo continua, prepara primeira aula e permite responder`  
   Prova UI completa do onboarding com objetivo, preparação, primeira aula e resposta.

Arquivo: `test/organism_vital_flow_test.dart`

7. `fluxo vital: objetivo -> T00 -> T02 -> aula -> A/B/C -> 1/2/3 -> motor -> janela`  
   Prova o fluxo vital pedagógico com T00, T02, aula, resposta e sinal.

Arquivo: `test/normal_lesson_full_completion_flow_test.dart`

8. `login valido -> T00/T02 -> 3 itens x 3 layers -> conclusao com persistencia`  
   Prova aula normal completa com três itens e três camadas, além de persistência.

## Comandos de validação

Executados com sucesso:

```bash
flutter analyze
flutter test test/session_regression_test.dart test/widget_test.dart test/organism_vital_flow_test.dart test/normal_lesson_full_completion_flow_test.dart
flutter test
```

## Resultado

Onboarding automatizado: FUNCIONANDO nos cenários cobertos por teste.

Limite honesto: esta prova não substitui teste manual em APK real com uma conta Supabase real e servidor real. Ela elimina a regressão reproduzida no código: token inválido transitório na preparação da aula agora força refresh e tenta novamente uma única vez.
