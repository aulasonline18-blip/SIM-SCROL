const express = require('express');

const PORT = Number(process.env.PORT || 3000);
const app = express();
const appRouter = require('./src/app/router');

app.use((req, res) => appRouter.router(req, res));

app.listen(PORT, '0.0.0.0', () => {
  console.log(`SIM API rodando em 0.0.0.0:${PORT}`);
});
