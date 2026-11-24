import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import path from 'path';
import { spawnSync } from 'child_process';

import { register, assistantContext, PLATFORM, COMMANDS, AGENTS } from '../src/index';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const read = (f: string) => fs.readFileSync(path.join(PKG, f), 'utf8');
const manifest = JSON.parse(read('package.json')).workspacePlugin;

test('the manifest names the platform, and every file it names ships', () => {
  assert.strictEqual(manifest.name, PLATFORM);
  const named = [...manifest.commands.files, ...manifest.scripts.functions, ...manifest.scripts.args, ...manifest.scripts.machine,
    ...manifest.ai.agents, ...manifest.ai.skills, ...manifest.ai.commands, ...manifest.ai.prompts, ...manifest.features];
  for (const f of named) assert.ok(fs.existsSync(path.join(PKG, f)), `${f} is in the package`);
  assert.deepStrictEqual(manifest.commands.files.map((f: string) => path.basename(f)), COMMANDS);
  assert.deepStrictEqual(manifest.ai.agents.map((f: string) => path.basename(f, '.md')), AGENTS);
  assert.deepStrictEqual(manifest.commands.types, ['sites'], 'the commands go to sites folders only');
  const files: string[] = JSON.parse(read('package.json')).files;
  for (const f of named) assert.ok(files.includes(f.split('/')[0]), `${f} is published with the package`);
  // The machine files land side by side in core/scripts/plugins/penpot/: no two may share a name.
  const names = manifest.scripts.machine.map((f: string) => path.basename(f));
  assert.strictEqual(new Set(names).size, names.length, 'the machine files have names of their own');
  assert.strictEqual(manifest.featuresSite, undefined, 'no site on Docker Compose for the browser suite: Penpot builds on DDEV only for now');
});

test('every command finds the workspace by itself, names its folder, and sources its args from where the installer puts them', () => {
  for (const f of manifest.commands.files) {
    const src = read(f);
    assert.match(src, /^#!\/usr\/bin\/env bash/, `${f} is a bash script`);
    assert.match(src, /WORKSPACE_SCRIPTS="\$\{WORKSPACE_SCRIPTS:-\$\(cd "\$\(dirname "\$\{BASH_SOURCE\[0\]\}"\)\/\.\.\/core\/scripts" && pwd\)\}"/, `${f} locates the tooling from its own path`);
    assert.match(src, /workspace\.__WORKSPACE__\.settings\.yml/, `${f} loads the settings of the folder it is installed into`);
    assert.match(src, /source \$\{WORKSPACE_SCRIPTS\}\/plugins\/penpot\/args\/arg-[a-z-]+\.sh \|\| exit 1 ;/, `${f} reads its arguments from the plugin's args`);
    const last = src.trim().split('\n').pop() as string;
    assert.match(read('scripts/functions/fun-penpot.sh'), new RegExp(`^function ${last.replace(/ ;$/, '')}\\(\\)`, 'm'), `${f} ends by calling a function the plugin defines`);
  }
  assert.match(read('commands/cmd-penpot-project.sh'), /^# workspace-name: Penpot/m, 'the builder carries the name the Build list shows');
  assert.doesNotMatch(read('commands/cmd-tools-penpot-cli.sh'), /^# workspace-name:/m, 'a tool is not a builder');
});

test('every shell script parses, and the site\'s scripts are Python the backend\'s container runs', () => {
  for (const f of [...manifest.commands.files, ...manifest.scripts.functions, ...manifest.scripts.args]) {
    const r = spawnSync('bash', ['-n', path.join(PKG, f)], { encoding: 'utf8' });
    assert.strictEqual(r.status, 0, `${f}: ${r.stderr}`);
  }
  for (const f of ['scripts/penpot-accounts.py', 'scripts/penpot-site.py']) {
    const r = spawnSync('python3', ['-c', 'import ast, sys; ast.parse(open(sys.argv[1]).read())', path.join(PKG, f)], { encoding: 'utf8' });
    assert.strictEqual(r.status, 0, `${f}: ${r.stderr}`);
  }
});

test('the runtime is DDEV: --runtime offers it alone, and the builder stops for another before it changes anything', () => {
  assert.match(read('scripts/args/arg-penpot.sh'), /choices=\['ddev'\]/, '--runtime has the one choice ddev');
  const src = read('scripts/functions/fun-penpot.sh');
  const build = src.slice(src.indexOf('function penpot_build()'));
  const guard = build.indexOf('if [ "$(penpot_runtime)" != \'ddev\' ] ; then');
  assert.ok(guard > 0, 'the builder asks the runtime');
  assert.ok(guard < build.indexOf('drop_database'), 'before it removes anything');
  assert.ok(guard < build.indexOf('ddev config'), 'and before ddev config');
  assert.match(build, /Penpot builds on DDEV only for now: its stack is not on the other runtimes yet \(webship\/workspace#694\)\. Build with --runtime ddev\./);
});

test('Penpot\'s services are the publisher\'s images, beside the project\'s web container, which keeps the mail catcher', () => {
  const compose = read('scripts/docker-compose.penpot.yaml');
  for (const image of ['penpotapp/frontend:${PENPOT_VERSION', 'penpotapp/backend:${PENPOT_VERSION', 'penpotapp/exporter:${PENPOT_VERSION', 'postgres:15', 'valkey/valkey:8.1']) {
    assert.ok(compose.includes(image), `the image ${image}`);
  }
  assert.match(compose, /VIRTUAL_HOST: \$\{DDEV_HOSTNAME\}/, 'the frontend takes the project\'s address');
  assert.match(compose, /HTTPS_EXPOSE=8457:80,8026:8025/, 'the web container moves, its mail catcher stays at :8026');
  assert.match(compose, /PENPOT_SMTP_HOST: web/, 'the site\'s mail goes to the mail catcher of the web container');
  assert.match(compose, /disable-admin-console/, 'no admin console, which needs a service of its own');
  assert.match(compose, /PENPOT_TELEMETRY_ENABLED: "false"/, 'no telemetry');
  assert.match(compose, /\$\{DDEV_APPROOT\}\/penpot:\/opt\/webship:ro/, 'the backend reads the plugin\'s scripts from the project');
  assert.match(compose, /name: ddev-\$\{DDEV_SITENAME\}-penpot-postgres/, 'the database volume is the project\'s');
});

test('the functions carry the names the core\'s tools look for, and run the site\'s tools in the backend\'s container', () => {
  const src = read('scripts/functions/fun-penpot.sh');
  for (const fn of ['set_penpot_users', 'add_penpot_users', 'cancel_penpot_users', 'testing_configure_penpot', 'penpot_build', 'penpot_cli_tool']) {
    assert.match(src, new RegExp(`^function ${fn}\\(\\) \\{`, 'm'), `${fn} is defined`);
  }
  assert.match(src, /--project-type=generic --project-name=\$\{PROJECT_NAME\} --omit-containers=db/, 'a generic project with no database of the container tool\'s own');
  assert.match(src, /--nodejs-version=\$\(ddev_nodejs_version\)/, 'the project carries the Node.js of the workspace rule');
  assert.match(src, /ddev exec -s penpot-backend "python3 \/opt\/webship\/penpot-accounts\.py"/, 'the accounts with the backend\'s own tool, in its container');
  assert.match(src, /penpot-site\.py --password-stdin http:\/\/localhost:6060/, 'the rest through the backend\'s own API, the password on the input');
  assert.match(src, /python3 manage\.py \$\{RUN\}/, 'the tool runs the backend\'s manage.py');
  assert.doesNotMatch(src, /ddev stop -y/, 'ddev stop takes no -y');
});

test('each agent is a definition the AI Agents folder can list: named after its file, described, on the fable model', () => {
  for (const f of manifest.ai.agents) {
    const src = read(f);
    const head = src.split('\n---\n')[0];
    assert.match(head, /^---\n/, `${f} opens with frontmatter`);
    assert.match(head, new RegExp(`^name: ${path.basename(f, '.md')}$`, 'm'));
    assert.match(head, /^description: .{80,}$/m, `${f} says when to use it`);
    assert.match(head, /^model: fable$/m);
    assert.match(head, /^tools:\n(  - \S+\n?)+/m);
    assert.match(src, /cmd-tools-testing\.sh|cmd-penpot-project\.sh/, `${f} names the plugin's commands`);
  }
  const tester = read('ai/agents/penpot-tester.md');
  assert.match(tester, /Never create or delete an account in a suite/);
  assert.match(tester, /No platform name in a step phrase/);
  assert.match(tester, /Playwright MCP browser first/);
});

test('register() adds the assistant context and nothing else', () => {
  const calls: string[] = [];
  const api: any = { name: 'penpot', addAssistantContext: (fn: () => string) => calls.push(fn()) };
  register(api);
  assert.strictEqual(calls.length, 1);
  assert.strictEqual(calls[0], assistantContext());
  for (const c of COMMANDS) assert.ok(calls[0].includes(c), `the assistant is told about ${c}`);
  for (const a of AGENTS) assert.ok(calls[0].includes(a), `the assistant is told about ${a}`);
});

test('the docs say container-based, name only what ships, and carry no personal value', () => {
  const docs = ['README.md', ...manifest.ai.agents, 'scripts/functions/fun-penpot.sh'];
  for (const f of docs) {
    const src = read(f);
    assert.doesNotMatch(src, /DDEV-only/i, `${f}: the workspace is container-based, DDEV by default`);
    assert.doesNotMatch(src, /\/home\/(?!YOUR_USER)[a-z]/, `${f} carries no personal path`);
    const mails = src.match(/[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[a-z]{2,}/g) || [];
    for (const m of mails) assert.match(m, /@example\.(com|org)$/, `${f}: ${m} is not an example address`);
  }
  for (const c of COMMANDS) assert.ok(read('README.md').includes(c), `the README lists ${c}`);
});
