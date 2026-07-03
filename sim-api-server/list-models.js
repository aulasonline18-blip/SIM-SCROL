const fs = require('fs');

for (const line of fs.readFileSync('.env', 'utf8').split(/\r?\n/)) {
  const idx = line.indexOf('=');
  if (idx > 0 && !process.env[line.slice(0, idx)]) {
    process.env[line.slice(0, idx)] = line.slice(idx + 1).trim();
  }
}

fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${encodeURIComponent(process.env.GEMINI_API_KEY)}`)
  .then((r) => r.json())
  .then((json) => {
    for (const model of json.models || []) {
      const methods = model.supportedGenerationMethods || [];
      if (methods.includes('generateContent')) {
        console.log(model.name);
      }
    }
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
