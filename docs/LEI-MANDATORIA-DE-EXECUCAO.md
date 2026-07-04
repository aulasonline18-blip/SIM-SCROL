# LEI MANDATORIA DE EXECUCAO DO SIM

Esta lei vale para qualquer alteracao futura no SIM-SCROL, no app Flutter, no servidor e nos artefatos de release.

## Regra absoluta

Nenhuma alteracao pode quebrar, reduzir, descontinuar, contornar ou enfraquecer uma funcao que ja esta funcionando.

Nenhuma alteracao pode ser feita sem referencia comprovada. A referencia deve ser uma destas:

1. Comportamento vivo do SimWeb, quando o comportamento existir no Web.
2. Comportamento vivo ja validado do proprio SIM-SCROL, quando o Web nao se aplicar.
3. Documentacao oficial da plataforma, biblioteca, loja, API ou framework envolvido.
4. Literatura tecnica reconhecida de engenharia de software, arquitetura, UX, acessibilidade, seguranca ou qualidade.

Se nao houver referencia, a alteracao e proibida ate a lacuna ser investigada e documentada.

Antes de tocar em qualquer caractere, o executor deve provar para si mesmo:

1. Qual funcao sera alterada.
2. Qual orgao correto deve receber a alteracao.
3. Qual comportamento vivo sera preservado.
4. Quais arquivos serao tocados.
5. Quais arquivos nao podem ser tocados.
6. Qual teste prova que nao houve regressao.
7. Qual rollback e possivel se algo falhar.
8. Qual referencia valida autoriza a alteracao.

## Lei de paridade com SimWeb

Antes de qualquer analise, correcao, refatoracao, teste ou release, o executor deve perguntar:

1. Esse comportamento existe no SimWeb?
2. Se existe, qual arquivo, funcao, rota ou componente do SimWeb e a fonte de verdade?
3. O SIM-SCROL esta copiando o comportamento funcional correto ou esta inventando uma regra diferente?
4. A diferenca e exigida pela plataforma mobile, pela Google Play, pela seguranca ou por uma arquitetura explicitamente melhor?
5. A diferenca foi documentada e testada?

Quando o SimWeb tiver o comportamento vivo correto, o SIM-SCROL deve seguir a mesma regra funcional, mesmo que a implementacao seja diferente.

Quando o SimWeb tiver uma arquitetura ruim mas um comportamento correto, o SIM-SCROL deve copiar o comportamento, nao a doenca arquitetural.

Quando o SimWeb nao tiver referencia aplicavel, o executor deve usar referencia oficial externa e registrar a fonte antes de alterar.

## Lei contra mudanca sem fonte

E proibido:

1. Corrigir por intuicao.
2. Alterar por gosto.
3. Trocar fluxo sem comparar com o SimWeb quando houver equivalente.
4. Redirecionar usuario, apagar sessao, cobrar credito, gerar imagem, gerar audio, sincronizar cloud, importar backup ou avancar aula sem referencia funcional.
5. Tratar erro tecnico de forma diferente do SimWeb sem justificar por plataforma, seguranca ou documentacao oficial.
6. Usar "parece melhor" como justificativa.

Toda tarefa deve deixar rastreavel no commit, teste ou relatorio qual referencia guiou a mudanca.

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

Tambem antes de editar, quando houver comportamento equivalente no SimWeb, localizar a referencia com leitura de codigo real. Exemplos de referencia aceitavel:

```bash
rg -n "nomeDaFuncao|rota|evento|erro|acao" /root/sim-work/sim-web/src
```

A leitura deve responder qual e o comportamento antes, durante e depois da acao.

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
