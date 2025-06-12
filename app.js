const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const path = require('path');

const app = express();
const server = http.createServer(app);
const io = socketIo(server);

// Serve static files (e.g., index.html, style.css, client.js)
app.use(express.static(path.join(__dirname)));

// Optional: Root route (for sanity check)
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

io.on('connection', socket => {
  console.log('User connected');
  socket.on('disconnect', () => console.log('User disconnected'));
});

server.listen(3000, () => console.log('Chat app running on port 3000'));




// const express = require('express');
// const http = require('http');
// const socketIo = require('socket.io');

// const app = express();
// const server = http.createServer(app);
// const io = socketIo(server);

// io.on('connection', socket => {
//     console.log('User connected');
//     socket.on('disconnect', () => console.log('User disconnected'));
// });

// server.listen(3000, () => console.log('Chat app running on port 3000'));
