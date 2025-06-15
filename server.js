import express from 'express';
import { WebSocketServer } from 'ws';
import pty from 'node-pty';
import { spawn } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const app = express();
const PORT = 3000;
const WS_PORT = 3001;

// Middleware
app.use(express.json());
app.use(express.static('public'));

// Environment setup
const CLAUDE_API_KEY = process.env.ANTHROPIC_API_KEY;
const GITHUB_SSH_KEY = process.env.GITHUB_SSH_KEY;
const REPO_URL = process.env.REPO_URL;
const WORKSPACE_DIR = '/workspace';

// Initialize Claude Code terminal
let claudeTerm = null;

// Setup function
async function setupEnvironment() {
  console.log('Setting up environment...');
  
  // Setup SSH key if provided
  if (GITHUB_SSH_KEY) {
    const fs = await import('fs');
    fs.writeFileSync('/root/.ssh/id_rsa', GITHUB_SSH_KEY, { mode: 0o600 });
    fs.writeFileSync('/root/.ssh/config', 'Host github.com\n  StrictHostKeyChecking no\n');
  }
  
  // Clone repository if URL provided
  if (REPO_URL) {
    await new Promise((resolve, reject) => {
      const git = spawn('git', ['clone', REPO_URL, WORKSPACE_DIR]);
      git.on('close', (code) => {
        if (code === 0) resolve();
        else reject(new Error(`Git clone failed with code ${code}`));
      });
    });
  }
  
  // Start Claude Code session
  const shell = process.platform === 'win32' ? 'powershell.exe' : 'bash';
  claudeTerm = pty.spawn(shell, [], {
    name: 'xterm-color',
    cols: 80,
    rows: 24,
    cwd: REPO_URL ? WORKSPACE_DIR : process.env.HOME,
    env: {
      ...process.env,
      ANTHROPIC_API_KEY: CLAUDE_API_KEY
    }
  });
  
  console.log('Environment setup complete');
}

// API Routes
app.get('/status', (req, res) => {
  res.json({
    ready: claudeTerm !== null,
    hasApiKey: !!CLAUDE_API_KEY,
    hasRepo: !!REPO_URL,
    workspace: REPO_URL ? WORKSPACE_DIR : process.env.HOME
  });
});

app.post('/git/:command', express.json(), async (req, res) => {
  const { command } = req.params;
  const validCommands = ['commit', 'push', 'pull', 'revert'];
  
  if (!validCommands.includes(command)) {
    return res.status(400).json({ error: 'Invalid git command' });
  }
  
  try {
    const gitArgs = [];
    
    switch(command) {
      case 'commit':
        const { message } = req.body;
        if (!message) return res.status(400).json({ error: 'Commit message required' });
        gitArgs.push('commit', '-m', message);
        break;
      case 'push':
        gitArgs.push('push');
        break;
      case 'pull':
        gitArgs.push('pull');
        break;
      case 'revert':
        gitArgs.push('revert', 'HEAD');
        break;
    }
    
    const git = spawn('git', gitArgs, { cwd: WORKSPACE_DIR });
    let output = '';
    
    git.stdout.on('data', (data) => { output += data; });
    git.stderr.on('data', (data) => { output += data; });
    
    git.on('close', (code) => {
      if (code === 0) {
        res.json({ success: true, output });
      } else {
        res.status(500).json({ error: 'Git command failed', output });
      }
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// WebSocket server for terminal
const wss = new WebSocketServer({ port: WS_PORT });

wss.on('connection', (ws) => {
  console.log('Terminal WebSocket connected');
  
  if (!claudeTerm) {
    ws.send('Terminal not initialized yet...');
    ws.close();
    return;
  }
  
  // Forward terminal output to browser
  const onData = claudeTerm.onData((data) => {
    ws.send(data);
  });
  
  // Forward browser input to terminal
  ws.on('message', (data) => {
    claudeTerm.write(data.toString());
  });
  
  // Handle resize
  ws.on('message', (data) => {
    try {
      const msg = JSON.parse(data.toString());
      if (msg.action === 'resize' && msg.cols && msg.rows) {
        claudeTerm.resize(msg.cols, msg.rows);
      }
    } catch (e) {
      // Not JSON, treat as terminal input
      claudeTerm.write(data.toString());
    }
  });
  
  ws.on('close', () => {
    console.log('Terminal WebSocket disconnected');
    onData.dispose();
  });
});

// Start servers
app.listen(PORT, async () => {
  console.log(`HTTP server running on port ${PORT}`);
  console.log(`WebSocket server running on port ${WS_PORT}`);
  
  try {
    await setupEnvironment();
  } catch (error) {
    console.error('Setup failed:', error);
  }
});