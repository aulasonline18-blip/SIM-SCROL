fetch('http://127.0.0.1:3000/api/complete-lesson', {
  method: 'POST',
  headers: {'content-type': 'application/json'},
  body: JSON.stringify({
    mode: 'lesson',
    item: 'fotossintese',
    stable_lang: 'Portuguese',
    layer: 1,
    err_count: 0,
    history: [],
  }),
})
  .then((r) => r.text())
  .then((text) => {
    console.log(text.slice(0, 1600));
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
