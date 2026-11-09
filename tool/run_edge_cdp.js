// Waits for the async benchmark page to finish, then prints its DOM output.
// Node 22 provides a global WebSocket, so no npm dependencies are needed.
const { spawn } = require('child_process');

const edge = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const profile =
  'C:\\Users\\Owner\\AppData\\Local\\Temp\\opencode\\xo_ai_async_cdp';
const port = 9333;
const pageUrl = 'file:///D:/xo_neon_app/tool/ai_async_bench.html';

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const child = spawn(
  edge,
  [
    '--headless=new',
    '--disable-gpu',
    '--no-sandbox',
    '--disable-background-timer-throttling',
    '--no-first-run',
    '--no-default-browser-check',
    `--user-data-dir=${profile}`,
    `--remote-debugging-port=${port}`,
    pageUrl,
  ],
  { stdio: 'ignore' },
);

async function findPage() {
  for (let i = 0; i < 150; i++) {
    try {
      const response = await fetch(`http://127.0.0.1:${port}/json/list`);
      const targets = await response.json();
      const page = targets.find((target) => target.type === 'page');
      if (page) {
        return page;
      }
    } catch (_) {
      // browser not ready yet
    }
    await sleep(200);
  }
  throw new Error('Edge DevTools endpoint did not become ready');
}

async function main() {
  const page = await findPage();
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    ws.onopen = resolve;
    ws.onerror = reject;
  });

  let nextId = 1;
  const pending = new Map();
  ws.onmessage = (event) => {
    const message = JSON.parse(event.data);
    if (message.id && pending.has(message.id)) {
      pending.get(message.id)(message);
      pending.delete(message.id);
    }
  };
  const send = (method, params = {}) => {
    const id = nextId++;
    ws.send(JSON.stringify({ id, method, params }));
    return new Promise((resolve) => pending.set(id, resolve));
  };

  let text = '';
  for (let i = 0; i < 400; i++) {
    const response = await send('Runtime.evaluate', {
      expression: `document.getElementById('out').textContent`,
      returnByValue: true,
    });
    text = response.result?.result?.value ?? '';
    if (text.includes('11x11 async')) {
      console.log(text);
      break;
    }
    await sleep(250);
  }
  if (!text.includes('11x11 async')) {
    console.error('benchmark did not finish; last output:');
    console.error(text);
    process.exitCode = 1;
  }

  try {
    await send('Browser.close');
  } catch (_) {
    // fall through to kill
  }
  ws.close();
  child.kill();
}

main().catch((error) => {
  console.error(error);
  child.kill();
  process.exit(1);
});
