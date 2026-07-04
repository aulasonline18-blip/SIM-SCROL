# LEI MANDATORIA DE EXECUCAO DO SIM

Esta lei vale para qualquer alteracao futura no SIM-SCROL, no app Flutter, no servidor e nos artefatos de release.

## Regra absoluta

Nenhuma alteracao pode quebrar, reduzir, descontinuar, contornar ou enfraquecer uma funcao que ja esta funcionando.

Antes de tocar em qualquer caractere, o executor deve provar para si mesmo:

1. Qual funcao sera alterada.
2. Qual orgao correto deve receber a alteracao.
3. Qual comportamento vivo sera preservado.
4. Quais arquivos serao tocados.
5. Quais arquivos nao podem ser tocados.
6. Qual teste prova que nao houve regressao.
7. Qual rollback e possivel se algo falhar.

## Proibicoes

E proibido:

1. Refatorar por gosto durante tarefa cirurgica.
2. Mudar T00, T02, aula, auth, credito, imagem, audio, sync, backup ou estado sem pedido explicito para esse orgao.
3. Criar mock ou fallback falso em producao.
4. Trocar fonte de verdade sem migracao e teste.
5. Mover logica pedagogica para UI.
6. Alterar package id, assinatura, billing ou servidor de producao sem registrar impacto de atualizacao.
7. Declarar pronto para Google Play sem build release, testes e checklist de politica.

## Portao antes de alterar

Antes de editar, executar pelo menos:

```bash
git status --short
```

Se houver alteracao nao relacionada, preservar. Nao reverter trabalho de outra pessoa.

## Portao depois de alterar

Toda mudanca deve ter validacao proporcional ao risco. Para release Android/Google Play, o minimo e:

```bash
flutter analyze
flutter test
flutter build appbundle --release --dart-define=FLUTTER_APP_MODE=production
```

Se servidor for alterado, tambem executar os testes do servidor.

## Criterio de conclusao

Uma tarefa so pode ser encerrada quando:

1. O escopo pedido foi atendido ou o bloqueio foi documentado.
2. As funcoes existentes seguem cobertas por teste ou prova manual.
3. Nao ha alteracao fora do escopo.
4. O working tree foi revisado.
5. O commit descreve exatamente a alteracao.

Esta lei deve ser tratada como parte da arquitetura do projeto.
