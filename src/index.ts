/**
 * Penpot for Webship Workspace: a platform plugin.
 *
 * What the package carries is placed by the installer from the manifest: the builder and the tool of the backend in
 * the sites folders, their functions and argparse under core/scripts/plugins/penpot/ (with the compose file of
 * Penpot's services, the scripts the builder runs in the backend's container, the sample files and the first feature
 * of a site), and its AI items (ai/ in this package) in the folder of their kind: the agents in AI Agents, the skill
 * in AI Skills, the command in AI Commands, the prompts in AI Prompts. The dashboard needs nothing drawn for it: the
 * builder is in the Build list because it is a cmd-*-project.sh, the row menus are the core's, the AI items are
 * listed like any other. What register() adds is what the assistant is told.
 *
 * Everything the dashboard is asked for goes through `api`; this package requires nothing from the dashboard's own
 * files, so it can be installed from npm and removed without a trace.
 */

import type { PluginApi } from '@webship.co/workspace-plugin-api';

/**
 * The plugin's name. A site is a generic project of the container tool with Penpot's services: the plugin claims it
 * with .ddev/config.penpot.yaml, and the core's tools call its functions under penpot.
 */
export const PLATFORM = 'penpot';

/** The commands the installer places in every sites folder. */
export const COMMANDS = ['cmd-penpot-project.sh', 'cmd-tools-penpot-cli.sh'];

/** The agents the installer places in the AI Agents folder. */
export const AGENTS = ['penpot-site-builder', 'penpot-tester'];

/** The skill the installer places in the AI Skills folder (a folder each, with its SKILL.md). */
export const SKILLS = ['penpot-scenarios'];

/** The slash command the installer places in the AI Commands folder. */
export const AI_COMMANDS = ['penpot-test'];

/** The prompts the installer places in the AI Prompts folder: each a whole launch command for a new session. */
export const PROMPTS = ['penpot-build-and-test', 'penpot-scenarios-for-an-area'];

/** What the assistant is told about Penpot in this workspace. */
export function assistantContext(): string {
  return [
    'Penpot (a plugin, @webship.co/workspace-penpot), the open-source design and prototyping platform: a site is built with',
    '`bash cmd-penpot-project.sh <name> --install --add-users` from a sites folder (dev, test, sandboxes, demos):',
    'the publisher\'s images (2.19.4 by default, `--penpot-version`) of its frontend, backend and exporter, with PostgreSQL and Valkey, as services of a generic project in containers,',
    'at https://<name>.ddev.site, its mail caught at https://<name>.ddev.site:8026; Penpot builds on DDEV only for now (`--runtime ddev`).',
    '`--install` makes the workspace account an account of the site, `--add-users` adds the default accounts in the team "Design team" (owner, admin: the members and their invitations, editor: the projects and the files, viewer: reads, comments, inspects), each @example.com;',
    '`--sample-content` adds the projects (Website redesign with Homepage and Pricing page, Brand with the shared library Style guide), the team\'s draft and the comment the step pack is tested on.',
    '`bash cmd-tools-penpot-cli.sh <name>` says what the site is and lists its accounts; `--run "<arguments>"` runs the backend\'s own tool (manage.py: create-profile, update-profile, delete-profile, search-profile) in its container,',
    '`--sample-content` adds the sample content later, `--tidy` removes the test content a stopped run left, `--add-users` and `--cancel-users` manage the default accounts.',
    '`bash cmd-tools-testing.sh <name>` sets up webship-js with the Penpot step pack; `--run` runs the suite.',
    `For Penpot work, hand over to the agents ${AGENTS.map((a) => `\`${a}\``).join(' and ')}.`,
    `The plugin also places the skill ${SKILLS.map((a) => `\`${a}\``).join(', ')} (the step pack's phrases, by area) in ai-skills/,`,
    `the command ${AI_COMMANDS.map((a) => `\`/${a} <site>\``).join(', ')} in ai-commands/ and the prompts ${PROMPTS.map((a) => `\`${a}\``).join(' and ')} in ai-prompts/.`,
    'Never run Penpot\'s tools on the host for a project; removing the project removes its database and its files too.',
  ].join(' ');
}

export function register(api: PluginApi): void {
  api.addAssistantContext(assistantContext);
}
