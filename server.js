import express from 'express';
import { WebSocketServer } from 'ws';
import pty from 'node-pty';
import { spawn } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const app = express();
const PORT = 3000;
const WS_PORT = 3001;

// Middleware
app.use(express.json());
app.use(express.static('public'));

// Environment setup
const CLAUDE_API_KEY = process.env.ANTHROPIC_API_KEY;
const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const WORKSPACE_DIR = '/workspace';
const GIT_USER_NAME = process.env.GIT_USER_NAME || 'ClaudeBox';
const GIT_USER_EMAIL = process.env.GIT_USER_EMAIL || 'claude@claudebox.local';

// Initialize Claude Code terminal
let claudeTerm = null;

// Setup function
async function setupEnvironment() {
  console.log('Setting up environment...');
  
  const fs = await import('fs');
  
  // Check if workspace exists and has content
  let workspaceExists = false;
  try {
    const files = fs.readdirSync(WORKSPACE_DIR);
    workspaceExists = files.length > 0;
  } catch (error) {
    console.log('No workspace directory found');
  }
  
  // Configure git
  console.log('Configuring git...');
  try {
    // Set git user config
    await new Promise((resolve, reject) => {
      spawn('git', ['config', '--global', 'user.email', 'claude@claudebox.local'])
        .on('close', (code) => code === 0 ? resolve() : reject(new Error('Failed to configure git email')));
    });
    
    await new Promise((resolve, reject) => {
      spawn('git', ['config', '--global', 'user.name', 'Claude'])
        .on('close', (code) => code === 0 ? resolve() : reject(new Error('Failed to configure git name')));
    });
    
    // Configure git with token if available
    if (GITHUB_TOKEN) {
      // Set up git credential helper
      await new Promise((resolve, reject) => {
        spawn('git', ['config', '--global', 'credential.helper', 'store'])
          .on('close', (code) => code === 0 ? resolve() : reject(new Error('Failed to configure git')));
      });
      
      // Store credentials
      const credentialUrl = `https://${GITHUB_TOKEN}:x-oauth-basic@github.com\n`;
      fs.writeFileSync('/root/.git-credentials', credentialUrl, { mode: 0o600 });
      
      console.log('Git authentication configured');
    }
  } catch (error) {
    console.error('Failed to configure git:', error);
  }
  
  // Start Claude Code session
  claudeTerm = pty.spawn('claude', [], {
    name: 'xterm-color',
    cols: 80,
    rows: 24,
    cwd: workspaceExists ? WORKSPACE_DIR : process.env.HOME,
    env: {
      ...process.env,
      ANTHROPIC_API_KEY: CLAUDE_API_KEY
    }
  });
  
  // Handle Claude process events
  claudeTerm.onExit(async (e) => {
    console.log(`Claude process exited with code ${e.exitCode}`);
    claudeTerm = null;
    terminalBuffer = ''; // Clear buffer when process exits
    
    // Notify connected clients
    wss.clients.forEach((client) => {
      if (client.readyState === 1) {
        client.send('\r\n[Claude process exited. Restarting...]\r\n');
      }
    });
    
    // Auto-restart after a short delay
    setTimeout(async () => {
      console.log('Restarting Claude process...');
      try {
        await setupEnvironment();
        
        // Notify clients of successful restart
        wss.clients.forEach((client) => {
          if (client.readyState === 1) {
            client.send('[Claude process restarted successfully]\r\n');
          }
        });
      } catch (error) {
        console.error('Failed to restart Claude:', error);
        wss.clients.forEach((client) => {
          if (client.readyState === 1) {
            client.send(`[Failed to restart Claude: ${error.message}]\r\n`);
          }
        });
      }
    }, 2000); // 2 second delay before restart
  });
  
  claudeTerm.onData((data) => {
    // Log Claude output for debugging
    process.stdout.write(data);
    
    // Add to buffer
    terminalBuffer += data;
    
    // Broadcast to all connected WebSocket clients
    wss.clients.forEach((client) => {
      if (client.readyState === 1) { // WebSocket.OPEN
        client.send(data);
      }
    });
  });
  
  console.log('Environment setup complete');
  console.log(`Working directory: ${workspaceExists ? WORKSPACE_DIR : process.env.HOME}`);
}

// API Routes
app.get('/status', (req, res) => {
  let hasRepo = false;
  
  try {
    const files = fs.readdirSync(WORKSPACE_DIR);
    hasRepo = files.length > 0;
  } catch (error) {
    // Workspace doesn't exist or is empty
  }
  
  res.json({
    ready: claudeTerm !== null,
    hasApiKey: !!CLAUDE_API_KEY,
    hasRepo: hasRepo,
    workspace: hasRepo ? WORKSPACE_DIR : process.env.HOME
  });
});

// Git stats endpoint
app.get('/git/stats', async (req, res) => {
  // Determine the correct working directory
  let gitWorkDir = WORKSPACE_DIR;
  try {
    const files = fs.readdirSync(WORKSPACE_DIR);
    if (files.length === 0) {
      gitWorkDir = process.env.HOME;
    }
  } catch (error) {
    gitWorkDir = process.env.HOME;
  }
  
  try {
    // Get git diff stats
    const gitDiff = spawn('git', ['diff', '--shortstat'], { cwd: gitWorkDir });
    let stats = '';
    
    gitDiff.stdout.on('data', (data) => { stats += data; });
    
    await new Promise((resolve) => {
      gitDiff.on('close', resolve);
    });
    
    // Parse stats (format: "X files changed, Y insertions(+), Z deletions(-)")
    let filesChanged = 0, insertions = 0, deletions = 0;
    
    const match = stats.match(/(\d+) files? changed(?:, (\d+) insertions?\(\+\))?(?:, (\d+) deletions?\(-\))?/);
    if (match) {
      filesChanged = parseInt(match[1]) || 0;
      insertions = parseInt(match[2]) || 0;
      deletions = parseInt(match[3]) || 0;
    }
    
    res.json({
      filesChanged,
      insertions,
      deletions,
      summary: stats.trim() || 'No changes'
    });
  } catch (error) {
    res.json({
      filesChanged: 0,
      insertions: 0,
      deletions: 0,
      summary: 'No git repository'
    });
  }
});

app.post('/git/:command', express.json(), async (req, res) => {
  const { command } = req.params;
  const validCommands = ['commit', 'push', 'pull', 'revert'];
  
  if (!validCommands.includes(command)) {
    return res.status(400).json({ error: 'Invalid git command' });
  }
  
  // Determine the correct working directory
  let gitWorkDir = WORKSPACE_DIR;
  try {
    const files = fs.readdirSync(WORKSPACE_DIR);
    if (files.length === 0) {
      gitWorkDir = process.env.HOME;
    }
  } catch (error) {
    gitWorkDir = process.env.HOME;
  }
  
  try {
    const gitArgs = [];
    
    switch(command) {
      case 'commit':
        const { message } = req.body;
        if (!message) return res.status(400).json({ error: 'Commit message required' });
        gitArgs.push('add', '-A');
        gitArgs.push('&&', 'git', 'commit', '-m', message);
        break;
      case 'push':
        gitArgs.push('push');
        break;
      case 'pull':
        gitArgs.push('pull');
        break;
      case 'revert':
        gitArgs.push('revert', 'HEAD', '--no-edit');
        break;
    }
    
    // For commit, we need to run two commands
    if (command === 'commit') {
      const { message } = req.body;
      // First add all files
      const addCmd = spawn('git', ['add', '-A'], { cwd: gitWorkDir });
      await new Promise((resolve) => {
        addCmd.on('close', resolve);
      });
      // Then commit
      gitArgs.length = 0;
      gitArgs.push('commit', '-m', message);
    }
    
    const git = spawn('git', gitArgs, { cwd: gitWorkDir });
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

// Terminal output buffer to store all output
let terminalBuffer = '';

// WebSocket server for terminal
const wss = new WebSocketServer({ port: WS_PORT });

wss.on('connection', (ws) => {
  console.log('Terminal WebSocket connected');
  
  if (!claudeTerm) {
    ws.send('Terminal not initialized yet...');
    ws.close();
    return;
  }
  
  // Send buffered output to new connection
  if (terminalBuffer.length > 0) {
    ws.send(terminalBuffer);
  }
  
  // Handle messages from browser
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
