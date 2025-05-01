const http = require('http');

const PORT = 2000;

const server = http.createServer((req, res) => {
  res.end('Hello from Dockerized Node.js App!');
});

server.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
