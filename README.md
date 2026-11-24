# @webship.co/workspace-penpot

Penpot, the open-source design and prototyping platform, for the [Webship Workspace](https://github.com/webship/workspace)
dashboard: a builder that makes a real Penpot site in containers, from the publisher's images (its frontend, backend
and exporter, with PostgreSQL and Valkey), its mail sent to the project's mail catcher; a tool that runs the backend's
own tool; the default accounts in a team, each in its role; optional sample content; the
[Penpot step pack](https://github.com/webship/penpot-steps) wired into the workspace's testing setup; and its AI items
— two agents, a skill, a command and two prompts — each listed in the workspace folder of its kind.

The workspace is container-based (DDEV by default): a site is a row like any other, so the row menus the core draws
(start, stop, launch, clone, remove, tests) work on it unchanged. The plugin claims its sites with a file of its own
(`.ddev/config.penpot.yaml`), so the Tests menu of the row offers the plugin's test users (see
[The default accounts](#the-default-accounts)).

It is made from the platform plugins of the workspace (the reference, `@webship.co/workspace-wordpress`, and those of
platforms with services of their own). Every call it makes to the containers is a plain verb of the container tool
(`config`, `start`, `exec`, `describe`, `launch`, `logs`), the way the workspace's own builders call it.

## Use it

```bash
cd ~/workspace
bash core/scripts/plugins.sh --require @webship.co/workspace-penpot --with-needs   # npm install into the dashboard
bash core/scripts/plugins.sh --activate penpot --with-needs                        # plugins.penpot in settings.yml
bash core/scripts/plugins.sh --install penpot                                      # commands, functions, args, AI items
bash core/scripts/plugins.sh --configure penpot                                    # nothing to configure: it has no settings file
```

The same four steps are buttons on the dashboard's **Settings → Plugins** page. `--install` is idempotent.
`--uninstall` removes what it placed; an AI item you edited stays. `--remove penpot` then takes the package out of
the dashboard.

Everything the plugin carries lands in the folder it belongs to, when that folder is an active workspace folder:

| What | Lands in |
| --- | --- |
| `cmd-penpot-project.sh`, `cmd-tools-penpot-cli.sh` | every active sites folder: `dev/`, `test/`, `sandboxes/`, `demos/` |
| The agents `penpot-site-builder`, `penpot-tester` | `ai-agents/` |
| The skill `penpot-scenarios` | `ai-skills/` |
| The command `/penpot-test` | `ai-commands/` |
| The prompts `penpot-build-and-test`, `penpot-scenarios-for-an-area` | `ai-prompts/` |

There they are listed like any other item of the folder, and installed into Claude Code from there.

## What it needs

A workspace starts empty, so the manifest says what else this plugin needs (`needs`):

- one sites folder, for the builder and the tool: `dev`, `test`, `sandboxes`, `demos` (`dev` is the one added when none is there). The folder also carries `cmd-tools-testing.sh` and the Users tools this plugin's hooks answer to.
- `ai-agents`, `ai-skills`, `ai-commands` and `ai-prompts`: the AI folders its agents, its skill, its command and its prompts are placed in.

`--require` says so, `--activate` and `--install` stop until the workspace has them, and `--with-needs` adds what is missing first:

```bash
bash core/scripts/plugins.sh --activate penpot --with-needs   # dev and the four AI folders are required, activated and installed first
bash core/scripts/plugins.sh --install penpot
```

Everything the builder runs for a site runs in containers, through the container tool the workspace already needs:
Penpot, its database and its files are the containers'; the accounts and the sample content are made by the plugin's
scripts in the backend's container. On the machine it uses Python 3 (which the workspace's own argument parsing
already needs). The plugin asks for no command of its own on the machine.

## What the package holds

| Path | What it is |
| --- | --- |
| `commands/cmd-penpot-project.sh` | The builder, in the Build list as **Penpot (design and prototyping)**, installed into every sites folder |
| `commands/cmd-tools-penpot-cli.sh` | The site's tool: what the site is and its accounts, the backend's own tool, the sample content, the test content a stopped run left, the default accounts |
| `scripts/functions/fun-penpot.sh` | The bash functions behind both, sourced by bootstrap once installed; the names the core's tools look for (`set_penpot_users`, `add_penpot_users`, `cancel_penpot_users`, `testing_configure_penpot`) |
| `scripts/args/arg-penpot.sh`, `arg-penpot-cli.sh` | Their argparse; the Build form draws the builder's flags from the first |
| `scripts/docker-compose.penpot.yaml` | Penpot's services in the project: the frontend (at the project's address), the backend, the exporter, PostgreSQL 15 and Valkey 8.1, and the settings of a test site |
| `scripts/penpot-accounts.py` | The accounts, with the backend's own tool (its prepl, which `manage.py` talks to), in the backend's container, the accounts on its input |
| `scripts/penpot-site.py` | The rest through Penpot's own API, as the accounts, in the backend's container (the step pack's own script): the onboarding seen, the team and its roles, the sample content, the clean-up of test content |
| `scripts/homepage.penpot`, `style-guide.penpot` | The two sample files the content imports: "Homepage" (the boards "Hero", a component with its "Button", and "Footer") and "Style guide" (the component "Logo") |
| `testing/site.feature` | The first feature a site gets when testing is set up |
| `ai/agents/penpot-site-builder.md` | The agent that builds and maintains sites with these commands |
| `ai/agents/penpot-tester.md` | The agent that writes and runs scenarios with the Penpot step pack |
| `ai/skills/penpot-scenarios/` | The skill: the step pack's phrases by area, the traps found on real sites, three example features |
| `ai/commands/penpot-test.md` | The slash command `/penpot-test <site>`: set up, match every step, run, report |
| `ai/prompts/penpot-build-and-test.md`, `penpot-scenarios-for-an-area.md` | Two prompts: whole launch commands for a new session |
| `src/index.ts` | `register(api)`: what the assistant is told about Penpot here |
| `features/penpot.feature` | Scenarios for the dashboard's own browser suite |

The `workspacePlugin` block in `package.json` is the manifest the installer reads. A site keeps a copy of the two
scripts and the two sample files in its `penpot/` folder, which the backend's container reads; each command of the
plugin brings that copy up to the installed plugin's first, so an update installed later reaches the sites built
before it.

## What is different from the reference

Penpot is not a PHP application: it is a frontend, a backend and an exporter of its publisher, each a container image,
with a PostgreSQL and a Valkey of their own. The plugin keeps the shape of the reference and changes this:

| | WordPress (the reference) | Penpot |
| --- | --- | --- |
| Project | `--project-type=wordpress`, nginx and PHP | `--project-type=generic --omit-containers=db`: Penpot's services in `.ddev/docker-compose.penpot.yaml`; the frontend takes the project's address, the project's web container moves to other ports and keeps the mail catcher |
| Recognised by | The project type | The file `.ddev/config.penpot.yaml`: the release, and the plugin's claim on the project |
| Getting the code | `wp core download` | The publisher's images (`penpotapp/frontend`, `penpotapp/backend`, `penpotapp/exporter`) at `--penpot-version` |
| Install | `wp core install` | Nothing to install: the backend makes its database at its first start; `--install` makes the workspace account an account of the site |
| Set up for testing | Nothing | Logins with a password, registration open, the verification of a new address off, no telemetry, the admin console off, a password recovery sent again after one second, each account having seen the onboarding and the release notes |
| Database | The container tool's MariaDB | Penpot's own PostgreSQL 15, a service of the project, its volume removed with the project |
| Mail | The container tool's mail catcher | The same: the backend sends over SMTP to the web container (`https://<name>.ddev.site:8026`) |
| Accounts | WP-CLI | The backend's own tool (its prepl), the accounts on its input; their team and roles through Penpot's own API |
| The CLI | WP-CLI | The backend's `manage.py`, through `cmd-tools-penpot-cli.sh --run` |
| The runtime | Every runtime of the workspace | DDEV only for now: the workspace's other runtimes build PHP stacks (webship/workspace#694); the builder says so and stops when another is asked for |
| Removing it | `ddev delete` | The same, with Penpot's database and files |
| Tests menu of the row | Reads the project type | The plugin's claim: the plugin's test users (`penpot`) |

No public domain, no hosted service and no account anywhere: the site answers at `https://<name>.ddev.site` through
the container tool's router. Only the open-source edition, self-hosted.

## The commands

Run them from a sites folder. `--help` is safe on both.

### Build a site

```bash
cd ~/workspace/dev
bash cmd-penpot-project.sh mysite --install --add-users                       # a site with its accounts
bash cmd-penpot-project.sh mydemo --install --add-users --sample-content      # with the sample projects, files and comment
bash cmd-penpot-project.sh mysite --install --add-users --penpot-version 2.19.4
```

| Flag | What it does |
| --- | --- |
| `--install` | Make the workspace account an account of the site. Without it the site has no account |
| `--add-users` | With `--install`: the default accounts in the team "Design team", each in its role |
| `--sample-content` | With `--install --add-users`: the content the step pack is tested on — the project "Website redesign" (pinned) with the files "Homepage" and "Pricing page", the project "Brand" with "Style guide" (a shared library with the component "Logo"), the team's draft "Sketches", and the editor's comment "Can the hero be taller?" on the board "Hero" |
| `--penpot-version <x.y.z>` | The release of the images: `2.19.4` by default |
| `--runtime ddev` | The container runtime: DDEV, the one Penpot builds on for now |
| `--launch` | Open the site when it is ready |

The site answers at `https://mysite.ddev.site` and its mail catcher at `https://mysite.ddev.site:8026`. A project of
the same name is deleted first, with its database and its files.

A build takes about five minutes the first time, most of it the download of the images (about 2 GB); a minute or two
after that. Check the free memory and disk first (`free -g`, `df -h /`), and build one site at a time on a machine
others use.

### Runtimes

Penpot builds on DDEV only for now. The workspace's other runtimes (Docker Compose, Podman, Kubernetes, Lando,
Docksal) build the stack of a PHP site, and Penpot is not one
([webship/workspace#694](https://github.com/webship/workspace/issues/694)). When the workspace's `container.runtime`
names another runtime, the builder says so and stops before it changes anything:

```
Penpot builds on DDEV only for now: its stack is not on the other runtimes yet (webship/workspace#694). Build with --runtime ddev.
```

`--runtime` takes the one choice `ddev`, so a build on such a workspace runs with `--runtime ddev`.

| | DDEV | Docker Compose, Podman, Kubernetes, Lando, Docksal |
| --- | --- | --- |
| Build, with the default accounts and the sample content | Yes | No: the builder stops and says why |
| The pages, and the login of each account in its role | Yes | Not built |
| `cmd-tools-penpot-cli.sh`: what the site is, `--run`, the accounts | Yes | Not built |
| Test users, cancelled and added with the core's tools | Yes | Not built |
| The mail the site sends, in the mail catcher | Yes | Not built |
| The testing setup and the suite | Yes | Not built |
| The row in the dashboard, and remove | Yes | Not built |

### Work on a site

```bash
bash cmd-tools-penpot-cli.sh mysite                                              # what the site is: release, addresses, accounts
bash cmd-tools-penpot-cli.sh mysite --run "search-profile -e editor@example.com"  # the backend's own tool, in its container
bash cmd-tools-penpot-cli.sh mysite --sample-content                             # the sample content, where it is missing
bash cmd-tools-penpot-cli.sh mysite --tidy                                       # remove the test content a stopped run left ("Webship test …")
bash cmd-tools-penpot-cli.sh mysite --add-users                                  # the default accounts, their team and their roles
bash cmd-tools-penpot-cli.sh mysite --cancel-users                               # delete them again
```

`--run` hands its words to the backend's `manage.py` (`create-profile`, `update-profile`, `delete-profile`,
`search-profile`) in its container. `--tidy` also puts the roles of the members and the onboarding of the accounts
back as the build made them. A new release of the site is a new build (`--penpot-version`): the plugin does not update
a site in place.

### The default accounts

| Account | Address | Role in "Design team" | Handle in the tests |
| --- | --- | --- | --- |
| `owner` | `owner@example.com` | Owner: everything of the team, its members and its settings | `owner` |
| `admin` | `admin@example.com` | Admin: the projects and the files, the members and their invitations | `admin` |
| `editor` | `editor@example.com` | Editor: the projects and the files | `editor` |
| `viewer` | `viewer@example.com` | Viewer: reads the files, comments on them and inspects them | `viewer` |

Each account has the password of the workspace's other default lists and logs in with its address; their names are
"Owner Test", "Admin Test", "Editor Test" and "Viewer Test". They are made with the backend's own tool, the accounts
on its input (never on a command line or in a file); an account that is there already gets its name and its password
back, and its role in the team. Each has seen the onboarding and the release notes of the release; each but `admin`
has answered the questionnaire of a new account (the step pack walks `admin`'s without sending it: answers once sent
stay on an account for good). Cancelling deletes them the way the backend's own tool does: they cannot log in any
more, and Penpot removes them after its deletion delay; adding them again makes them anew, in a new team "Design
team" (`--sample-content` puts the sample content back). An account of your own, and the workspace account,
stay when the default accounts are added or cancelled. They are for local sites and for tests.

The row's Tests menu offers **Add the test users** and **Cancel the test users** for a site this plugin claims: they
run the same list as

```bash
bash cmd-tools-add-users.sh mysite penpot       # the core's tool, with the plugin's list
bash cmd-tools-cancel-users.sh mysite penpot
```

### Test a site

```bash
bash cmd-tools-testing.sh mysite                  # webship-js, the step pack, the users registry, a first feature
bash cmd-tools-testing.sh mysite --run            # run the suite in the container
bash cmd-tools-testing.sh mysite --run --path tests/features/site.feature
```

`cmd-tools-testing.sh` is the workspace's own. For a site it also adds `@webship-js/penpot-steps` to `package.json`,
lists its step definitions in `cucumber.js` after webship-js's own, writes the mail catcher, the account that prepares
and removes test content (`owner`), the team the scenarios work in ("Design team"), the users registry (the handles
above, overridable with `PENPOT_<HANDLE>_EMAIL` and `PENPOT_<HANDLE>_PASSWORD`), the tags that keep the pack's
assertions that must fail out of a normal run, and the site's address in place of the starter's
`http://localhost:8080`. It places `tests/features/site.feature` when the project has none, and makes sure the default
accounts are on the site. Run it again and it adds what is missing and keeps what you changed.

A scenario of your own reads like this one, from the step pack's phrases (the skill `penpot-scenarios` lists them by
area):

```gherkin
Feature: The workspace
  Scenario: A board drawn and sized, a rectangle in it, read in the Inspect tab
    Given there is a new file "Webship test file" in the project "Webship test project"
    And I am a logged in user with the "editor" user
    When I open the file "Webship test file"
    And I draw a "Board" on the canvas
    And I set the design value "Width" to "300"
    And I set the design value "Height" to "200"
    Then the selection should measure "300 x 200"
    When I draw a "Rectangle" in the board "Board"
    And I set the design value "Width" to "120"
    And I open the "Inspect" tab
    Then the inspect panel "Size and position" should show "Width" as "120px"
    And the layers should list "Rectangle"
```

`tests/features/site.feature` passes on a site built with `--install --add-users`, with or without the sample
content, and the features of the step pack pass on a site built with `--sample-content`. The pack's features have
names of their own (`dashboard.feature`, `workspace.feature`, …): copying them beside `site.feature` replaces nothing.

## The AI items

`ai/` in the package holds one folder per kind, the manifest's `ai` block names each item, and `--install` places it
in the workspace folder of that kind.

| Kind | Item | Use it to |
| --- | --- | --- |
| Agent | `penpot-site-builder` | Build, maintain or remove a site with the commands above, in containers only |
| Agent | `penpot-tester` | Set the testing stack up, look at the site in the Playwright MCP browser first, write scenarios from the pack's steps and run them; it never creates an account in a suite and never writes a platform name into a step phrase |
| Skill | `penpot-scenarios` | Write a scenario from phrases that exist: the pack's steps by area, the handles of the users registry, the traps found on real sites, and three features that pass on a site with the sample content and the default accounts |
| Command | `/penpot-test <site> [feature or @tag]` | Run the suite of a site from inside a session: set up when missing, match every step, run, report what failed and why |
| Prompt | `penpot-build-and-test` | Start a session that builds a site, says what it is, sets the testing stack up and runs the first feature |
| Prompt | `penpot-scenarios-for-an-area` | Start a session that writes and runs the scenarios of one area of a site |

After `--install` each is in its folder on the dashboard. **Install** there puts an agent, a skill or a command into
Claude Code (`~/.claude/agents`, `~/.claude/skills`, `~/.claude/commands`), or from the command line:

```bash
cd ~/workspace/ai-agents   && bash cmd-tools-ai-items.sh penpot-tester --install
cd ~/workspace/ai-skills   && bash cmd-tools-ai-items.sh penpot-scenarios --install
cd ~/workspace/ai-commands && bash cmd-tools-ai-items.sh penpot-test --install
```

A prompt is not installed: it is the whole `claude …` launch command of a new session, and the dashboard's **New
screen** form lists it as a template. By hand, fill the placeholders in and run the command of the file from the
folder it names.

The items are written for any AI CLI, with Claude Code as the default shape: the frontmatter and the file layout are
Claude Code's, the body of each item is plain Markdown that names no tool or feature of one CLI, a command says in
words what its arguments are, and the text between the triple quotes of a prompt can be given to another AI CLI as it
is.

Every step phrase the items show is checked against the definitions of the step pack and of webship-js
(`tests/fixtures/step-definitions.txt`), and every command and flag against the plugin's own.

## Develop it

```bash
npm install     # builds dist/ (TypeScript)
npm run lint
npm test        # the manifest, the commands, the AI items, the functions against a scaffolded project
```

CI runs the same on Node.js 24 and 26, parses every shell script, and runs the plugin's `features/penpot.feature`
against a dashboard with this plugin installed (`webship/workspace/.github/workflows/plugin-browser-suite.yml`).

The Penpot name is a trademark of its owner; this plugin is not affiliated with or endorsed by them.

## License

ISC (see `LICENSE`).
