# Contas de Credito de Teste

As contas de credito de teste do SIM-API devem ser configuradas por variavel de ambiente, nunca hardcoded no codigo.

Variavel:

```env
TEST_CREDIT_EMAILS=joelgomes522@gmail.com,aulasonline18@gmail.com,ccrfoodgy1@gmail.com
```

Saldo de teste padrao:

```env
TEST_CREDIT_BALANCE=999999
```

Motivo:

- permite testar fluxos de imagem paga sem compra real;
- evita regra financeira escondida no codigo;
- permite alterar contas de teste sem novo deploy de codigo;
- mantem o `.env` real fora do git.

Ultima configuracao aplicada no servidor:

- `joelgomes522@gmail.com`
- `aulasonline18@gmail.com`
- `ccrfoodgy1@gmail.com`
