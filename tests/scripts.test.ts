import test, { after } from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { spawnSync } from 'child_process';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const FUNCTIONS = path.join(PKG, 'scripts', 'functions', 'fun-penpot.sh');

// The cucumber.js webship-js scaffolds, as far as the testing hook reads it.
const SCAFFOLD = `module.exports = {
  default: {
    requireModule: ['tsx/cjs'],
    require: [
      'node_modules/webship-js/tests/step-definitions/**/*.js',          // Webship-js core step definitions.
      'tests/step-definitions/**/*.js',                                  // Your custom step definitions.
    ],
    paths: ['tests/features/**/*.feature'],
    worldParameters: {
      launchUrl: process.env.LAUNCH_URL || 'http://localhost:8080',
    },
  },
};
`;

/**
 * A project folder with the testing stack scaffolded, and the tooling folder the installer would have filled.
 * A site of this plugin has the builder's .ddev/config.penpot.yaml.
 */
// Every folder a test makes goes when the tests are done.
const ROOTS: string[] = [];
after(() => {
  for (const root of ROOTS) fs.rmSync(root, { recursive: true, force: true });
});

function project(kind: 'penpot' | 'drupal') {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'penpot-plugin-'));
  ROOTS.push(root);
  const dir = path.join(root, 'dev', 'site1');
  fs.mkdirSync(path.join(dir, '.ddev'), { recursive: true });
  fs.writeFileSync(path.join(dir, '.ddev', 'config.yaml'), `name: site1\ntype: ${kind === 'penpot' ? 'generic' : 'drupal11'}\n`);
  if (kind === 'penpot') fs.writeFileSync(path.join(dir, '.ddev', 'config.penpot.yaml'), 'web_environment:\n  - PENPOT_VERSION=2.19.4\n');
  fs.writeFileSync(path.join(dir, 'cucumber.js'), SCAFFOLD);
  fs.writeFileSync(path.join(dir, 'package.json'), JSON.stringify({ name: 'site1', devDependencies: { 'webship-js': '^2.0.16' } }, null, 2));
  const scripts = path.join(root, 'core', 'scripts');
  const plugin = path.join(scripts, 'plugins', 'penpot');
  fs.mkdirSync(plugin, { recursive: true });
  for (const f of ['testing/site.feature', 'scripts/docker-compose.penpot.yaml', 'scripts/penpot-accounts.py', 'scripts/penpot-site.py', 'scripts/homepage.penpot', 'scripts/style-guide.penpot']) {
    fs.copyFileSync(path.join(PKG, f), path.join(plugin, path.basename(f)));
  }
  return { root, dir, scripts };
}

/**
 * Run bash with the plugin's functions sourced and `ddev` replaced by a recorder of its calls and of the first line
 * it reads on stdin (`stdin1:`). A call that asks the site with curl gets 200, as a site that answers.
 */
function bash(script: string, env: Record<string, string> = {}) {
  const fake = 'ddev() { echo "ddev $*" >> "${DDEV_LOG:-/dev/null}" ; case "$*" in *curl*) echo 200 ;; esac ; if [ ! -t 0 ] ; then IFS= read -r first ; [ -n "${first}" ] && echo "  stdin1: ${first}" >> "${DDEV_LOG:-/dev/null}" ; cat > /dev/null ; fi ; return 0 ; }';
  return spawnSync('bash', ['-c', `${fake}\nsource ${FUNCTIONS}\n${script}`], { encoding: 'utf8', env: { ...process.env, ...env } });
}

/** The JSON a recorded call of penpot-accounts.py carried on the first line of its input. */
function accountsOf(recorded: string): any[] {
  const lines = recorded.split('\n');
  const call = lines.findIndex((l) => l === 'ddev exec -s penpot-backend python3 /opt/webship/penpot-accounts.py');
  assert.ok(call >= 0, `a call of the accounts script: ${recorded}`);
  const m = (lines[call + 1] || '').match(/^  stdin1: ([A-Za-z0-9+/=]+)$/);
  assert.ok(m, `the first line of its input carries the accounts: ${lines[call + 1]}`);
  return JSON.parse(Buffer.from(m![1], 'base64').toString('utf8'));
}

const OWNER = { account_name: 'owner1', account_mail: 'owner1@example.com', account_pass: 'Owner-pass-1234' };

test('the default accounts are the owner, an admin, an editor and a viewer of the team, with example addresses', () => {
  const r = bash('set_penpot_users ; for u in "${users[@]}" ; do n="user_${u}_name" ; m="user_${u}_mail" ; p="user_${u}_password" ; g="user_${u}_role" ; f="user_${u}_fullname" ; echo "${!n}|${!m}|${!p}|${!g}|${!f}" ; done');
  assert.strictEqual(r.status, 0, r.stderr);
  const rows = r.stdout.trim().split('\n').map((l) => l.split('|'));
  assert.deepStrictEqual(rows.map((x) => x[0]), ['owner', 'admin', 'editor', 'viewer']);
  assert.deepStrictEqual(rows.map((x) => x[4]), ['Owner Test', 'Admin Test', 'Editor Test', 'Viewer Test'], 'the names the step pack\'s registry gives them');
  for (const [name, mail, password, role] of rows) {
    assert.strictEqual(mail, `${name}@example.com`);
    assert.strictEqual(role, name);
    assert.ok(password.length >= 10, 'a password every common password rule accepts');
  }
});

test('the accounts are made with the backend\'s own tool, then their team and roles through the site\'s API, never a password on a command line', () => {
  const p = project('penpot');
  const log = path.join(p.root, 'ddev.log');
  const r = bash('set_penpot_users ; add_penpot_users', { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log, ...OWNER });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const recorded = fs.readFileSync(log, 'utf8');
  const accounts = accountsOf(recorded);
  assert.deepStrictEqual(accounts.map((a) => [a.fullname, a.email, a.action]), [
    ['Owner Test', 'owner@example.com', undefined],
    ['Admin Test', 'admin@example.com', undefined],
    ['Editor Test', 'editor@example.com', undefined],
    ['Viewer Test', 'viewer@example.com', undefined],
  ]);
  assert.ok(accounts.every((a) => a.password === 'dD.123123ddd'));
  assert.match(recorded, /^ddev exec -s penpot-backend PENPOT_MAIN_VERSION=2\.19 python3 \/opt\/webship\/penpot-site\.py --password-stdin http:\/\/localhost:6060 props team$/m, 'the onboarding seen, then the team and its roles');
  const site = recorded.split('\n').findIndex((l) => l.includes('penpot-site.py'));
  assert.strictEqual(Buffer.from(recorded.split('\n')[site + 1].replace('  stdin1: ', ''), 'base64').toString('utf8'), 'dD.123123ddd', 'the password comes on its input');
  for (const call of recorded.split('\n').filter((l) => l.startsWith('ddev '))) {
    assert.doesNotMatch(call, /Owner-pass|dD\./, `no password on a command line: ${call}`);
  }
  assert.deepStrictEqual(fs.readdirSync(p.dir).filter((f) => !['.ddev', 'cucumber.js', 'package.json'].includes(f)), [], 'no file with a password is left in the project');
});

test('a site built before the plugin was updated reads the installed plugin\'s scripts at the next call', () => {
  const p = project('penpot');
  const files = path.join(p.dir, 'penpot');
  fs.mkdirSync(files, { recursive: true });
  for (const f of ['penpot-accounts.py', 'penpot-site.py', 'homepage.penpot', 'style-guide.penpot']) fs.writeFileSync(path.join(files, f), 'an older copy\n');
  const r = bash('penpot_enter_project && pwd', { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1' });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  assert.strictEqual(r.stdout.trim(), p.dir);
  for (const f of ['penpot-accounts.py', 'penpot-site.py', 'homepage.penpot', 'style-guide.penpot']) {
    assert.ok(fs.readFileSync(path.join(files, f)).equals(fs.readFileSync(path.join(p.scripts, 'plugins', 'penpot', f))), `${f} is the installed plugin's`);
  }
});

test('the default accounts are deleted, the workspace account kept', () => {
  const p = project('penpot');
  const log = path.join(p.root, 'ddev.log');
  const r = bash('set_penpot_users ; cancel_penpot_users', { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log, ...OWNER });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const accounts = accountsOf(fs.readFileSync(log, 'utf8'));
  assert.deepStrictEqual(accounts.map((a) => [a.email, a.action]), [
    ['owner@example.com', 'delete'], ['admin@example.com', 'delete'], ['editor@example.com', 'delete'], ['viewer@example.com', 'delete'],
  ]);
  assert.ok(!accounts.some((a) => a.email === OWNER.account_mail), 'never the workspace account');
});

test('the builder stops when the workspace runs another runtime, before it changes anything', () => {
  const p = project('penpot');
  const log = path.join(p.root, 'ddev.log');
  for (const runtime of ['docker', 'podman', 'kubernetes', 'lando', 'docksal']) {
    // The core's runtime layer: --runtime, else the workspace's container.runtime (fun-runtime.sh's runtime_of).
    const layer = 'runtime_of() { local a="${RUNTIME:-_none_}" ; [ "${a}" = _none_ ] && a="" ; echo "${a:-${container_runtime:-ddev}}" ; } ;';
    const r = bash(`${layer} trim_project_name() { : ; } ; drop_database() { echo "dropped" ; } ; penpot_build`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log, RUNTIME: '_none_', container_runtime: runtime, INSTALL: 'yes', ADD_USERS: 'yes', ...OWNER });
    assert.strictEqual(r.status, 1, `${runtime}: ${r.stdout}`);
    assert.match(r.stdout, /Penpot builds on DDEV only for now: its stack is not on the other runtimes yet \(webship\/workspace#694\)\. Build with --runtime ddev\./);
    assert.doesNotMatch(r.stdout, /dropped/, `${runtime}: nothing was removed`);
  }
  assert.ok(!fs.existsSync(log), 'and the container tool was never called');
  assert.ok(fs.existsSync(path.join(p.dir, '.ddev', 'config.penpot.yaml')), 'the project is as it was');
});

test('the builder refuses what it cannot build, and says why, before it changes anything', () => {
  const p = project('penpot');
  const cases: [Record<string, string>, RegExp][] = [
    [{ PENPOT_VERSION: 'latest' }, /--penpot-version takes a release \(2\.19\.4\), not latest\. Nothing was changed\./],
    [{ ADD_USERS: 'yes' }, /--add-users needs --install/],
    [{ INSTALL: 'yes', SAMPLE_CONTENT: 'yes' }, /--sample-content needs --add-users/],
    [{ INSTALL: 'yes', account_pass: '' }, /The workspace account's password is not set/],
  ];
  for (const [vars, message] of cases) {
    const r = bash('trim_project_name() { : ; } ; drop_database() { echo "dropped" ; } ; penpot_build', { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', RUNTIME: 'ddev', ...OWNER, ...vars });
    assert.strictEqual(r.status, 1, r.stdout);
    assert.match(r.stdout, message);
    assert.doesNotMatch(r.stdout, /dropped/);
  }
  const r = bash('trim_project_name() { : ; } ; drop_database() { echo "dropped" ; } ; penpot_build', { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'Site_1', RUNTIME: 'ddev', ...OWNER });
  assert.match(r.stdout, /must be small letters, digits and dashes/);
});

test('the project\'s files: Penpot\'s services, the release with a secret key of its own, the claim, and the scripts the backend reads', () => {
  const p = project('penpot');
  const target = path.join(p.root, 'dev', 'site2');
  fs.mkdirSync(target);
  const r = bash(`penpot_write_config "${target}" 2.19.4 && cat "${target}/.ddev/.env"`, { WORKSPACE_SCRIPTS: p.scripts });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  assert.match(r.stdout, /^PENPOT_VERSION=2\.19\.4$/m);
  assert.match(r.stdout, /^PENPOT_SECRET_KEY=[A-Za-z0-9]{40,}$/m, 'a secret key of the site\'s own');
  assert.ok(fs.readFileSync(path.join(target, '.ddev', 'docker-compose.penpot.yaml'), 'utf8').includes('penpotapp/backend'));
  assert.match(fs.readFileSync(path.join(target, '.ddev', 'config.penpot.yaml'), 'utf8'), /^  - PENPOT_VERSION=2\.19\.4$/m, 'the claim of the plugin, with the release');
  assert.deepStrictEqual(fs.readdirSync(path.join(target, 'penpot')).sort(), ['homepage.penpot', 'penpot-accounts.py', 'penpot-site.py', 'style-guide.penpot']);
  const again = bash(`penpot_write_config "${target}" 2.19.4 && cat "${target}/.ddev/.env"`, { WORKSPACE_SCRIPTS: p.scripts });
  assert.notStrictEqual(again.stdout, r.stdout, 'each build its own key');
});

test('the testing hook wires the step pack, the mail catcher, the managing account, the team and the users registry, once', () => {
  const p = project('penpot');
  const env = { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', ...OWNER };
  const r = bash(`testing_configure_penpot "${p.dir}"`, env);
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const pkg = JSON.parse(fs.readFileSync(path.join(p.dir, 'package.json'), 'utf8'));
  assert.strictEqual(pkg.devDependencies['@webship-js/penpot-steps'], '^2.0.0');
  const src = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
  assert.ok(src.indexOf('node_modules/webship-js/tests/step-definitions') < src.indexOf('node_modules/@webship-js/penpot-steps/tests/step-definitions'), 'the pack after webship-js');
  assert.match(src, /tags: process\.env\.CUCUMBER_TAGS \|\| 'not @wip and not @must-fail',/);
  assert.match(src, /mailUrl: process\.env\.MAIL_URL \|\| `\$\{\(process\.env\.LAUNCH_URL \|\| 'https:\/\/site1\.ddev\.site'\)/);
  assert.match(src, /manager: process\.env\.MANAGER \|\| 'owner',/);
  assert.match(src, /team: process\.env\.TEAM \|\| 'Design team',/);
  for (const [handle, name] of [['owner', 'Owner Test'], ['admin', 'Admin Test'], ['editor', 'Editor Test'], ['viewer', 'Viewer Test']]) {
    assert.ok(src.includes(`${handle}: { email: process.env.PENPOT_${handle.toUpperCase()}_EMAIL || '${handle}@example.com', password: process.env.PENPOT_${handle.toUpperCase()}_PASSWORD || 'dD.123123ddd', name: '${name}' },`), `the registry has ${handle}`);
  }
  assert.ok(!src.includes('owner1'), 'never the workspace account');
  assert.match(src, /launchUrl: process\.env\.LAUNCH_URL \|\| 'https:\/\/site1\.ddev\.site',/, 'the site\'s address');
  assert.ok(fs.existsSync(path.join(p.dir, 'tests', 'features', 'site.feature')), 'a first feature');
  const again = bash(`testing_configure_penpot "${p.dir}"`, env);
  assert.strictEqual(again.status, 0, again.stderr + again.stdout);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), src, 'a second run changes nothing');
});

test('the testing hook leaves a project of another platform as it is', () => {
  const p = project('drupal');
  const before = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
  const r = bash(`testing_configure_penpot "${p.dir}"`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', ...OWNER });
  assert.strictEqual(r.status, 0, r.stderr);
  assert.strictEqual(r.stdout, '');
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), before);
});
