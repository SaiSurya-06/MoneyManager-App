const express = require('express');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const app = express();
const PORT = process.env.PORT || 3000;
const DATA_FILE = path.join(__dirname, 'db.json');
const VERSION_FILE = path.join(__dirname, 'versions.json');
const AUTH_FILE = path.join(__dirname, 'auth.json');

// --- In-Memory Rate Limiter ---
const requestCounts = new Map();
const RATE_LIMIT_WINDOW_MS = 60000; // 1 minute
const RATE_LIMIT_MAX_REQUESTS = 60; // 60 requests per minute

function rateLimiter(req, res, next) {
  const ip = req.ip || req.socket.remoteAddress || 'unknown';
  const now = Date.now();
  const record = requestCounts.get(ip) || { count: 0, startTime: now };

  if (now - record.startTime > RATE_LIMIT_WINDOW_MS) {
    record.count = 1;
    record.startTime = now;
  } else {
    record.count++;
  }
  requestCounts.set(ip, record);

  if (record.count > RATE_LIMIT_MAX_REQUESTS) {
    return res.status(429).send('Error: Too many requests. Please try again later.');
  }
  next();
}

app.use(rateLimiter);
app.use(express.text({ limit: '10mb' }));

// --- Storage Utilities ---
function readJson(file) {
  try {
    if (fs.existsSync(file)) {
      return JSON.parse(fs.readFileSync(file, 'utf8'));
    }
  } catch (e) {
    console.error(`Error reading file ${file}:`, e.message);
  }
  return {};
}

function writeJson(file, data) {
  try {
    fs.writeFileSync(file, JSON.stringify(data, null, 2), 'utf8');
  } catch (e) {
    console.error(`Error writing file ${file}:`, e.message);
  }
}

function verifyAuth(key, token) {
  const auths = readJson(AUTH_FILE);
  if (!auths[key]) {
    if (token) {
      auths[key] = crypto.createHash('sha256').update(token).digest('hex');
      writeJson(AUTH_FILE, auths);
      return true;
    }
    return true; // backwards compatibility if no token was set on creation
  }
  if (!token) return false;
  const hash = crypto.createHash('sha256').update(token).digest('hex');
  return auths[key] === hash;
}

// Health check
app.get('/', (req, res) => {
  const { action } = req.query;
  if (action === 'test') {
    return res.send('ok');
  }
  res.send('ok');
});

// Get data (full or incremental by version)
app.get('/sync', (req, res) => {
  const { key, since_version, auth_token } = req.query;
  if (!key) return res.status(400).send('Error: Missing key parameter');

  if (!verifyAuth(key, auth_token)) {
    return res.status(401).send('Error: Unauthorized access to sync room');
  }

  const db = readJson(DATA_FILE);
  if (db[key] === undefined) return res.send('404');

  if (since_version && parseInt(since_version) > 0) {
    const versions = readJson(VERSION_FILE);
    const keyVersion = versions[key] || 0;
    const since = parseInt(since_version);

    if (keyVersion <= since) {
      return res.send(JSON.stringify({ changes: [], version: keyVersion, isIncremental: true }));
    }

    return res.send(JSON.stringify({
      changes: db[key],
      version: keyVersion,
      isIncremental: true
    }));
  }

  res.send(db[key]);
});

// Backward compatibility endpoint for GET /?action=get
app.get('/api', (req, res) => {
  const { action, key, since_version, auth_token } = req.query;
  if (action === 'test') return res.send('ok');
  if (action === 'get' || key) {
    if (!key) return res.status(400).send('Error: Missing key parameter');
    if (!verifyAuth(key, auth_token)) {
      return res.status(401).send('Error: Unauthorized access to sync room');
    }
    const db = readJson(DATA_FILE);
    if (db[key] === undefined) return res.send('404');
    
    if (since_version && parseInt(since_version) > 0) {
      const versions = readJson(VERSION_FILE);
      const keyVersion = versions[key] || 0;
      if (keyVersion <= parseInt(since_version)) {
        return res.send(JSON.stringify({ changes: [], version: keyVersion, isIncremental: true }));
      }
      return res.send(JSON.stringify({
        changes: db[key],
        version: keyVersion,
        isIncremental: true
      }));
    }
    return res.send(db[key]);
  }
  res.send('ok');
});

// Set data (full or chunked)
app.post('/', (req, res) => {
  const { key, action, auth_token, checksum } = req.query;
  const value = req.body;

  if (!key) return res.status(400).send('Error: Missing key parameter');
  if (value === undefined || value === null) return res.status(400).send('Error: Missing body content');

  if (!verifyAuth(key, auth_token)) {
    return res.status(401).send('Error: Unauthorized access to sync room');
  }

  const db = readJson(DATA_FILE);
  const versions = readJson(VERSION_FILE);

  // Chunk assembly
  if (action === 'set_chunk') {
    const { index, total, val } = req.query;
    const idx = parseInt(index);
    const tot = parseInt(total);

    if (isNaN(idx) || isNaN(tot) || idx < 0 || idx >= tot) {
      return res.status(400).send('Error: Invalid chunk index or total bounds');
    }

    const chunkKey = `${key}_chunks`;
    if (!db[chunkKey]) db[chunkKey] = {};
    db[chunkKey][idx] = val || value;

    const receivedCount = Object.keys(db[chunkKey]).length;
    if (receivedCount === tot) {
      let assembled = '';
      for (let i = 0; i < tot; i++) {
        assembled += db[chunkKey][i] || '';
      }

      // Checksum validation
      if (checksum) {
        const computedChecksum = crypto.createHash('sha256').update(assembled).digest('hex');
        if (computedChecksum !== checksum) {
          delete db[chunkKey];
          writeJson(DATA_FILE, db);
          return res.status(400).send('Error: Chunk assembly checksum mismatch');
        }
      }

      db[key] = assembled;
      delete db[chunkKey];
      versions[key] = (versions[key] || 0) + 1;
      writeJson(DATA_FILE, db);
      writeJson(VERSION_FILE, versions);
      return res.send(`chunk_received:${idx};assembled;v:${versions[key]}`);
    }

    writeJson(DATA_FILE, db);
    return res.send(`chunk_received:${idx};partial:${receivedCount}/${tot}`);
  }

  // Integrity Checksum Validation for full payload
  if (checksum) {
    const computedChecksum = crypto.createHash('sha256').update(value).digest('hex');
    if (computedChecksum !== checksum) {
      return res.status(400).send('Error: Payload checksum mismatch');
    }
  }

  db[key] = value;
  versions[key] = (versions[key] || 0) + 1;
  writeJson(DATA_FILE, db);
  writeJson(VERSION_FILE, versions);

  res.send(JSON.stringify({ status: 'ok', version: versions[key] }));
});

app.listen(PORT, () => {
  console.log(`Money Manager Sync Server running on port ${PORT}`);
});
