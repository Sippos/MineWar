const WebSocket = require('ws');
const wss = new WebSocket.Server({ port: process.env.PORT || 3000 });

const rooms = {};

wss.on('connection', function connection(ws) {
  ws.room = null;
  ws.role = null;

  ws.on('message', function incoming(message) {
    let data;
    try {
      data = JSON.parse(message);
    } catch(e) { return; }

    if (data.type === 'join') {
      const roomCode = data.room;
      ws.room = roomCode;
      
      if (!rooms[roomCode]) {
        // First person to join becomes the host
        rooms[roomCode] = { host: ws, client: null };
        ws.role = 'host';
        ws.send(JSON.stringify({ type: 'joined', role: 'host' }));
      } else if (!rooms[roomCode].client) {
        // Second person becomes the client
        rooms[roomCode].client = ws;
        ws.role = 'client';
        ws.send(JSON.stringify({ type: 'joined', role: 'client' }));
        
        // Notify host
        rooms[roomCode].host.send(JSON.stringify({ type: 'peer_connected' }));
      } else {
        ws.send(JSON.stringify({ type: 'error', message: 'Room full' }));
      }
    } else if (ws.room && rooms[ws.room]) {
      // Forward WebRTC handshakes (SDP / ICE candidates) to the other peer
      const room = rooms[ws.room];
      const target = (ws.role === 'host') ? room.client : room.host;
      if (target && target.readyState === WebSocket.OPEN) {
        target.send(message.toString());
      }
    }
  });

  ws.on('close', function() {
    if (ws.room && rooms[ws.room]) {
      const room = rooms[ws.room];
      const target = (ws.role === 'host') ? room.client : room.host;
      if (target && target.readyState === WebSocket.OPEN) {
        target.send(JSON.stringify({ type: 'peer_disconnected' }));
      }
      delete rooms[ws.room];
    }
  });
});

console.log("Signaling server running on port", process.env.PORT || 3000);
