# LEI MANDATORIA DE EXECUCAO DO SIM

Esta lei vale para qualquer alteracao futura no SIM-SCROL, no app Flutter, no servidor e nos artefatos de release.

## Regra absoluta

Nenhuma alteracao pode quebrar, reduzir, descontinuar, contornar ou enfraquecer uma funcao que ja esta funcionando.

Nenhuma alteracao pode ser feita sem referencia comprovada. A referencia deve ser uma destas:

1. Comportamento vivo ja validado do proprio SIM-SCROL.
2. Comportamento vivo ja validado do servidor oficial do SIM-SCROL, quando a funcao depender do servidor.
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

## Lei de independencia do SimWeb

O SIM-SCROL/App Flutter, o servidor oficial do SIM-SCROL e o SimWeb sao produtos/repositorios independentes.

Nenhuma regra, teste, auditoria, documento de paridade ou comparacao historica pode obrigar o SIM-SCROL ou o servidor a copiar, espelhar, igualar ou sincronizar comportamento com o SimWeb.

O SimWeb pode ser lido apenas como referencia historica opcional quando o usuario pedir explicitamente. Essa leitura nao torna o SimWeb fonte de verdade do SIM-SCROL.

O sistema visual do SIM-SCROL e do servidor oficial e independente do sistema visual do SimWeb. Diferencas visuais entre eles sao permitidas e nao sao, por si so, erro, regressao ou obrigacao de correcao.

Qualquer alteracao no SIM-SCROL deve preservar o comportamento vivo do proprio SIM-SCROL, a Planta-Mae, as leis de seguranca, os contratos do servidor oficial e os testes proprios do app/servidor.

## Lei contra mudanca sem fonte

E proibido:

1. Corrigir por intuicao.
2. Alterar por gosto.
3. Trocar fluxo sem referencia valida do proprio SIM-SCROL, do servidor oficial ou de documentacao tecnica aplicavel.
4. Redirecionar usuario, apagar sessao, cobrar credito, gerar imagem, gerar audio, sincronizar cloud, importar backup ou avancar aula sem referencia funcional.
5. Tratar erro tecnico de forma diferente dos contratos proprios do SIM-SCROL sem justificar por plataforma, seguranca ou documentacao oficial.
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

Tambem antes de editar, quando houver comportamento equivalente no proprio SIM-SCROL ou no servidor oficial, localizar a referencia com leitura de codigo real. Exemplos de referencia aceitavel:

```bash
rg -n "nomeDaFuncao|rota|evento|erro|acao" /root/SIM-SCROL/lib /root/SIM-SCROL/test /root/sim-work/sim-api/src /root/sim-work/sim-api/test
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
