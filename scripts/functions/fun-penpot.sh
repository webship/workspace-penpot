#!/usr/bin/env bash

# Penpot for the Webship Workspace: build a site of Penpot (the open-source design and prototyping platform) from the
# publisher's images, run the backend's own tool, add its default accounts and their team, add its sample content,
# and wire its step pack into the testing setup.
#
# Placed by `plugins.sh --install penpot` in core/scripts/plugins/penpot/functions/, where bootstrap sources it after
# the core's own functions. Everything runs in containers, never on the host: Penpot's frontend, backend and exporter,
# with PostgreSQL and Valkey, are services of a generic project of the container tool (.ddev/docker-compose.penpot.yaml,
# from the plugin's docker-compose.penpot.yaml); the frontend takes the project's address, the project's own web
# container keeps the mail catcher, which takes the site's mail. The accounts are made with the backend's own tool
# (its prepl, which manage.py talks to) and the rest through Penpot's own API, by the plugin's scripts run in the
# backend's container. The open-source edition itself: no account anywhere, no hosted service, no telemetry.
#
# The runtimes: Penpot is not a PHP site, and the workspace's other runtimes build PHP stacks only for now. A site is
# built on DDEV; asked for another runtime (--runtime, or the workspace's container.runtime), the builder says so and
# stops before it changes anything (webship/workspace#694).
#
# The container tool has no project type for Penpot, so a site of this plugin is recognised by a file
# (.ddev/config.penpot.yaml, written by the builder). Four names are the ones the core's tools look for:
#   set_penpot_users          the default accounts                     (cmd-tools-add-users.sh <project> penpot)
#   add_penpot_users          make them, and their team                (the same tool, and --add-users of the builder)
#   cancel_penpot_users       delete them                              (cmd-tools-cancel-users.sh <project> penpot)
#   testing_configure_penpot  the step pack in the testing stack       (cmd-tools-testing.sh <project>)

# The step pack a site is tested with, and the release line it is required at.
readonly PENPOT_STEPS_PACKAGE='@webship-js/penpot-steps';
readonly PENPOT_STEPS_VERSION='^2.0.0';

# The release the builder runs when none is asked for (a tag of the publisher's images).
readonly PENPOT_DEFAULT_VERSION='2.19.4';

# The team the default accounts work in, and the folder of the project the plugin's scripts are copied to (the
# backend's container reads them at /opt/webship).
readonly PENPOT_TEAM='Design team';
readonly PENPOT_FILES='penpot';

# The default accounts, the ones a scenario logs in as: the owner of the team "Design team", an admin of it (the
# members and their invitations), an editor (the projects and the files) and a viewer (reads, comments, inspects).
# Accounts are configuration, made once on the site; a test suite never creates or deletes one. The workspace account
# the builder makes with --install is an account of its own and is not in this list.
function set_penpot_users() {
  users=(owner admin editor viewer);
  local user ;
  for user in "${users[@]}" ; do
    printf -v "user_${user}_name" '%s' "${user}" ;
    printf -v "user_${user}_mail" '%s' "${user}@example.com" ;
    printf -v "user_${user}_password" '%s' 'dD.123123ddd' ;
    printf -v "user_${user}_role" '%s' "${user}" ;
    printf -v "user_${user}_fullname" '%s' "${user^} Test" ;
  done
}

# The runtime of the project in this folder, or of a new build (--runtime, else the workspace's setting, else DDEV).
# A core without the runtime layer has DDEV only.
function penpot_runtime() {
  if declare -f runtime_of > /dev/null ; then runtime_of ; else echo 'ddev' ; fi
}

# The address of a site: https://<name>.ddev.site.
function penpot_url() {
  echo "https://${1:-${PROJECT_NAME}}.ddev.site" ;
}

# Is this folder a Penpot site of this plugin? The builder leaves .ddev/config.penpot.yaml in it.
function penpot_is_project() {
  [ -f "$1/.ddev/config.penpot.yaml" ] ;
}

# Go to the project a tool was asked about, or say why not.
function penpot_enter_project() {
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}";
  if [ ! -d "${project_path}" ] ; then
    echo "No project ${PROJECT_NAME} in ${WORKSPACE_ROOT}/${doc_name}." ;
    return 1 ;
  fi
  if ! penpot_is_project "${project_path}" ; then
    echo "${doc_name}/${PROJECT_NAME} is not a Penpot site of this plugin (it has no .ddev/config.penpot.yaml)." ;
    return 1 ;
  fi
  penpot_refresh_files "${project_path}" || return 1 ;
  cd "${project_path}" || return 1 ;
}

# The site's copy of the plugin's scripts and sample files (penpot/, which the backend's container reads), brought up
# to the installed plugin's, so a plugin updated with --install reaches the sites built before it. The compose file is
# left as it is: a change to it takes a restart.
function penpot_refresh_files() {
  local project_path="$1" from="${WORKSPACE_SCRIPTS}/plugins/penpot" f ;
  [ -d "${project_path}/${PENPOT_FILES}" ] || return 0 ;
  for f in penpot-accounts.py penpot-site.py homepage.penpot style-guide.penpot ; do
    if [ -f "${from}/${f}" ] && ! cmp -s "${from}/${f}" "${project_path}/${PENPOT_FILES}/${f}" ; then
      cp "${from}/${f}" "${project_path}/${PENPOT_FILES}/${f}" || return 1 ;
    fi
  done
}

# A value of the site's own settings file (.ddev/config.penpot.yaml): PENPOT_VERSION.
function penpot_setting() {
  sed -n "s/^  - $1=\\(.*\\)\$/\\1/p" "${2:-.}/.ddev/config.penpot.yaml" 2>/dev/null | head -n 1 ;
}

# The main version of a release, the one the release notes are of: 2.19 for 2.19.4.
function penpot_main_version() {
  echo "$1" | cut -d. -f1-2 ;
}

# Write the project's files: Penpot's services (.ddev/docker-compose.penpot.yaml), the release and a secret key of the
# site's own (.ddev/.env), the claim of the plugin (.ddev/config.penpot.yaml), and the plugin's scripts and sample
# files in penpot/, which the backend's container reads.
function penpot_write_config() {
  local project_path="$1" version="$2" ;
  local from="${WORKSPACE_SCRIPTS}/plugins/penpot" ;
  local f ;
  for f in docker-compose.penpot.yaml penpot-accounts.py penpot-site.py homepage.penpot style-guide.penpot ; do
    if [ ! -f "${from}/${f}" ] ; then
      echo "${f} is not in ${from}: install the plugin (plugins.sh --install penpot)." ;
      return 1 ;
    fi
  done
  mkdir -p "${project_path}/.ddev" "${project_path}/${PENPOT_FILES}" || return 1 ;
  cp "${from}/docker-compose.penpot.yaml" "${project_path}/.ddev/docker-compose.penpot.yaml" || return 1 ;
  for f in penpot-accounts.py penpot-site.py homepage.penpot style-guide.penpot ; do
    cp "${from}/${f}" "${project_path}/${PENPOT_FILES}/${f}" || return 1 ;
  done
  local secret ;
  secret="$(head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 48)" ;
  printf 'PENPOT_VERSION=%s\nPENPOT_SECRET_KEY=%s\n' "${version}" "${secret}" > "${project_path}/.ddev/.env" || return 1 ;
  cat > "${project_path}/.ddev/config.penpot.yaml" <<YAMLEOF
# Penpot in this project: its services (docker-compose.penpot.yaml), the release in .env. Written by the Penpot
# builder of the workspace; build again rather than editing by hand.
web_environment:
  - PENPOT_VERSION=${version}
YAMLEOF
}

# Wait until the site answers: its front page, and its API through the frontend (asked from the project's web
# container, on the project's own network).
function penpot_wait() {
  local attempt front api ;
  for attempt in $(seq 1 120) ; do
    front="$(ddev exec "curl -s -o /dev/null -w '%{http_code}' http://penpot-frontend:8080/" < /dev/null 2>/dev/null | tr -d '\r' | tail -1)" ;
    api="$(ddev exec "curl -s -o /dev/null -w '%{http_code}' -H 'Accept: application/json' -X POST http://penpot-frontend:8080/api/main/methods/get-profile" < /dev/null 2>/dev/null | tr -d '\r' | tail -1)" ;
    if [ "${front}" == '200' ] && [ "${api}" == '200' ] ; then
      return 0 ;
    fi
    sleep 3 ;
  done
  echo "Penpot did not answer (the front page ${front:-none}, the API ${api:-none}); the end of its backend's log:" ;
  ddev logs -s penpot-backend --tail 40 < /dev/null 2>/dev/null ;
  return 1 ;
}

# The release the site runs, as its backend says it.
function penpot_version() {
  ( cd "${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}" 2>/dev/null && ddev exec -s penpot-backend "cat /opt/penpot/backend/version.txt" < /dev/null 2>/dev/null ) | tr -d '\r' | head -n 1 ;
}

# Rows of accounts for penpot-accounts.py, as the base64 of its JSON list: "fullname|email|password|action" lines in
# PENPOT_ROWS, which travel to Python in the environment, never on a command line.
function penpot_accounts_payload() {
  PENPOT_ROWS="$1" python3 -c '
import base64, json, os
rows = []
for line in os.environ["PENPOT_ROWS"].split("\x1e"):
    if not line:
        continue
    fullname, email, password, action = line.split("\x1f")
    row = {"fullname": fullname, "email": email, "password": password}
    if action:
        row["action"] = action
    rows.append(row)
print(base64.b64encode(json.dumps(rows).encode()).decode())' ;
}

# Run penpot-accounts.py in the backend's container with a payload on its input (the base64 of the accounts).
function penpot_accounts() {
  printf '%s\n' "$1" | ddev exec -s penpot-backend "python3 /opt/webship/penpot-accounts.py" ;
}

# Run verbs of penpot-site.py (props, team, content, tidy, list) in the backend's container, against the backend's
# own API, with the default accounts' password on its input.
function penpot_site() {
  local password="$1" version="$2" ; shift 2 ;
  printf '%s\n' "$(printf '%s' "${password}" | base64 -w0)" \
    | ddev exec -s penpot-backend "PENPOT_MAIN_VERSION=$(penpot_main_version "${version}") python3 /opt/webship/penpot-site.py --password-stdin http://localhost:6060 $*" ;
}

# Build a Penpot site from nothing: the project and Penpot's services; with --install the workspace account as an
# account of the site; with --add-users the default accounts in the team "Design team"; with --sample-content the
# projects, files and comment the step pack is tested on.
function penpot_build() {
  trim_project_name ;
  local base_url ; base_url="$(penpot_url)" ;
  local version="${PENPOT_VERSION:-${site_penpot_version:-${PENPOT_DEFAULT_VERSION}}}" ;
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}" ;

  # Not a PHP site: the workspace's other runtimes do not build its stack yet (webship/workspace#694).
  if [ "$(penpot_runtime)" != 'ddev' ] ; then
    echo "Penpot builds on DDEV only for now: its stack is not on the other runtimes yet (webship/workspace#694). Build with --runtime ddev." ;
    exit 1 ;
  fi
  if ! [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ; then
    echo "--penpot-version takes a release (2.19.4), not ${version}. Nothing was changed." ;
    exit 1 ;
  fi
  if [ "${ADD_USERS}" == 'yes' ] && [ "${INSTALL}" != 'yes' ] ; then
    echo "--add-users needs --install: the default accounts go into the site --install sets up." ;
    exit 1 ;
  fi
  if [ "${SAMPLE_CONTENT}" == 'yes' ] && [ "${ADD_USERS}" != 'yes' ] ; then
    echo "--sample-content needs --add-users: the sample projects belong to the team of the default accounts." ;
    exit 1 ;
  fi
  if [ ${#PROJECT_NAME} -gt 40 ] || ! [[ "${PROJECT_NAME}" =~ ^[a-z0-9][a-z0-9-]*$ ]] ; then
    echo "The project name ${PROJECT_NAME} must be small letters, digits and dashes (its address and its containers take it). Nothing was changed." ;
    exit 1 ;
  fi
  if [ "${INSTALL}" == 'yes' ] && [ ${#account_pass} -lt 8 ] ; then
    echo "The workspace account's password is not set (core/config/settings.yml): --install makes it an account of the site. Nothing was changed." ;
    exit 1 ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name} || exit 1 ;

  # A project of the same name goes first, with its containers and its volumes (Penpot's database and files).
  drop_database ;
  rm -rf "${PROJECT_NAME:?}" ;
  mkdir -p "${PROJECT_NAME}" ;
  cd "${project_path}" || exit 1 ;

  # A generic project with no database of the container tool's own (Penpot has its own PostgreSQL), and the Node.js
  # of the workspace for a test suite run in the web container.
  ddev config --project-type=generic --project-name=${PROJECT_NAME} --omit-containers=db \
    --nodejs-version=$(ddev_nodejs_version) < /dev/null || exit 1 ;
  penpot_write_config "${project_path}" "${version}" || exit 1 ;

  echo "Starting the project and Penpot ${version}: its images are about 2 GB the first time." ;
  ddev_up start -y < /dev/null || exit 1 ;
  penpot_wait || exit 1 ;

  if [ "${INSTALL}" == 'yes' ] ; then
    echo "Making the workspace account an account of the site." ;
    local rows ;
    rows="${account_name}"$'\x1f'"${account_mail:-${account_name}@example.com}"$'\x1f'"${account_pass}"$'\x1f'$'\x1e' ;
    penpot_accounts "$(penpot_accounts_payload "${rows}")" || { echo "The workspace account could not be made." ; exit 1 ; } ;
    if [ "${ADD_USERS}" == 'yes' ] ; then
      set_penpot_users ;
      add_penpot_users || exit 1 ;
      if [ "${SAMPLE_CONTENT}" == 'yes' ] ; then
        echo "Adding the sample content: the projects Website redesign and Brand, their files, a draft and a comment." ;
        ( cd "${project_path}" && penpot_site 'dD.123123ddd' "${version}" content ) || exit 1 ;
      fi
      users=() ;
    fi
    echo "${doc_name} ${PROJECT_NAME} has been installed: Penpot $(penpot_version).";
    echo "The site: ${base_url} · its mail: ${base_url}:8026";
    echo "The workspace account logs in with ${account_mail:-${account_name}@example.com}.";
  else
    echo "${doc_name} ${PROJECT_NAME} is ready, without accounts: Penpot $(penpot_version) at ${base_url}.";
    echo "Build it again with --install (and --add-users) to make the workspace account and the default accounts.";
  fi

  if [ "${LAUNCH}" == 'yes' ] ; then
    ddev launch "${base_url}" ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name};
}

# Make the default accounts with the backend's own tool, or give them back their names and passwords, then the team
# "Design team" with each in its role, and the onboarding and release notes of a new account marked as seen (each but
# admin having answered the questionnaire, which a scenario walks without sending it). The list is loaded by the
# caller (set_penpot_users): the core's add_users, the builder, the tool.
function add_penpot_users() {
  penpot_enter_project || return 1 ;
  local user user_name user_mail user_password user_role user_fullname rows="" ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    user_password="user_${user}_password"; user_role="user_${user}_role"; user_fullname="user_${user}_fullname";

    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo "      User mail: ${!user_mail}";
    echo "  User password: ${!user_password}";
    echo "      User role: ${!user_role} of ${PENPOT_TEAM}";
    echo " ================================================================= ";
    rows="${rows}${!user_fullname}"$'\x1f'"${!user_mail}"$'\x1f'"${!user_password}"$'\x1f'$'\x1e' ;
  done
  local version ; version="$(penpot_setting PENPOT_VERSION)" ;
  penpot_accounts "$(penpot_accounts_payload "${rows}")" \
    && penpot_site 'dD.123123ddd' "${version:-${PENPOT_DEFAULT_VERSION}}" props team ;
  local status=$? ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${status} ;
}

# Delete the default accounts from the site, the way the backend's own tool does (never the workspace account).
function cancel_penpot_users() {
  penpot_enter_project || return 1 ;
  local user user_name user_mail rows="" ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo "      User mail: ${!user_mail}";
    echo " ================================================================= ";
    rows="${rows}"$'\x1f'"${!user_mail}"$'\x1f'$'\x1f''delete'$'\x1e' ;
  done
  penpot_accounts "$(penpot_accounts_payload "${rows}")" ;
  local status=$? ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${status} ;
}

# What cmd-tools-penpot-cli.sh does: the first of --run, --add-users, --cancel-users, --sample-content, --tidy that
# was asked for; with none of them, what the site is and its accounts.
function penpot_cli_tool() {
  trim_project_name ;
  penpot_enter_project || exit 1 ;

  if ! ddev describe -j 2>/dev/null | grep -q '"status":"running"' ; then
    ddev start -y < /dev/null || exit 1 ;
  fi
  penpot_wait > /dev/null || { echo "Penpot of ${PROJECT_NAME} does not answer; start it again (ddev restart in ${doc_name}/${PROJECT_NAME})." ; exit 1 ; } ;
  local version ; version="$(penpot_setting PENPOT_VERSION)" ; version="${version:-${PENPOT_DEFAULT_VERSION}}" ;

  if [ ! "${RUN}" == '_none_' ] ; then
    # The backend's own tool (manage.py: create-profile, update-profile, delete-profile, search-profile), in its
    # container.
    ddev exec -s penpot-backend "cd /opt/penpot/backend && python3 manage.py ${RUN}" < /dev/null ;
    exit $? ;
  fi

  set_penpot_users ;
  if [ "${ADD_USERS}" == 'yes' ] ; then
    add_penpot_users ;
  elif [ "${CANCEL_USERS}" == 'yes' ] ; then
    cancel_penpot_users ;
  elif [ "${SAMPLE_CONTENT}" == 'yes' ] ; then
    penpot_site 'dD.123123ddd' "${version}" content list ;
  elif [ "${TIDY}" == 'yes' ] ; then
    # What a run that was stopped half way left, then the roles and the onboarding of the accounts as the build made them.
    penpot_site 'dD.123123ddd' "${version}" tidy team props ;
  else
    echo "${doc_name}/${PROJECT_NAME}: Penpot $(penpot_version)" ;
    echo "  the site:  $(penpot_url)" ;
    echo "  its mail:  $(penpot_url):8026" ;
    echo "" ;
    echo "Accounts:" ;
    local user user_mail rows="" ;
    for user in "${users[@]}" ; do user_mail="user_${user}_mail"; rows="${rows}"$'\x1f'"${!user_mail}"$'\x1f'$'\x1f''search'$'\x1e' ; done
    penpot_accounts "$(penpot_accounts_payload "${rows}")" ;
  fi
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# The step pack in the testing stack of a Penpot site. The core's testing_configure calls this in the project folder
# once webship-js is scaffolded and before the dependencies are installed; for a project that is not one of this
# plugin's it changes nothing.
#
# It adds the pack to package.json, lists its step definitions in cucumber.js after webship-js's own, gives
# cucumber.js the tags that keep the pack's assertions that must fail out of a normal run, the mail catcher, the
# account that prepares and removes test content (manager), the team the scenarios work in, and the users registry of
# the default accounts (a handle a scenario reads, mapped to an account; never the workspace account), and writes a
# first feature when the project has none of its own. Every part is skipped when it is already there, so a second run
# adds what the first missed and never resets a suite.
function testing_configure_penpot() {
  local project_path="$1";
  penpot_is_project "${project_path}" || return 0 ;
  if [ ! -f "${project_path}/cucumber.js" ] || [ ! -f "${project_path}/package.json" ] ; then
    echo "  Penpot: cucumber.js is not here yet — run the testing setup again once webship-js is scaffolded." ;
    return 1 ;
  fi

  echo "Adding the Penpot step pack (${PENPOT_STEPS_PACKAGE} ${PENPOT_STEPS_VERSION}).";
  set_penpot_users ;
  local registry="" user user_mail user_password user_fullname ;
  for user in "${users[@]}" ; do
    user_mail="user_${user}_mail"; user_password="user_${user}_password"; user_fullname="user_${user}_fullname";
    registry="${registry}${user}|${!user_mail}|${!user_password}|${!user_fullname}"$'\n' ;
  done

  local site_name ;
  site_name="$(sed -n 's/^name:[[:space:]]*"\{0,1\}\([A-Za-z0-9._-]*\)"\{0,1\}[[:space:]]*$/\1/p' "${project_path}/.ddev/config.yaml" | head -n 1)" ;

  python3 - "${project_path}" "${PENPOT_STEPS_PACKAGE}" "${PENPOT_STEPS_VERSION}" 'PENPOT' "${registry}" "$(penpot_url "${site_name:-${PROJECT_NAME}}")" "${PENPOT_TEAM}" <<'PYEOF' || return 1
import json, re, sys

project, pack, version, prefix, registry, address, team = sys.argv[1:8]

# package.json: the pack as a dev dependency, at the release line this plugin was proven on.
pkg_file = project + '/package.json'
pkg = json.load(open(pkg_file))
if pack not in pkg.get('dependencies', {}) and pack not in pkg.get('devDependencies', {}):
    pkg.setdefault('devDependencies', {})[pack] = version
    open(pkg_file, 'w').write(json.dumps(pkg, indent=4) + '\n')
    print('  package.json: %s %s' % (pack, version))

cucumber_file = project + '/cucumber.js'
src = open(cucumber_file).read()
before = src

if ('node_modules/%s/' % pack) not in src:
    line = "'node_modules/%s/tests/step-definitions/**/*.js'," % pack
    core = re.search(r"^([ \t]*)'node_modules/webship-js/tests/step-definitions/[^']*',.*$", src, re.M)
    opening = re.search(r"^([ \t]*)require:[ \t]*\[[ \t]*$", src, re.M)
    if core:
        src = src[:core.end()] + '\n' + core.group(1) + line + src[core.end():]
    elif opening:
        src = src[:opening.end()] + '\n' + opening.group(1) + '  ' + line + src[opening.end():]
    else:
        sys.exit("  cucumber.js has no require list this can add to. Add this line to it:\n    " + line)
    print('  cucumber.js: the step definitions of %s' % pack)

if not re.search(r"^[ \t]*tags:", src, re.M):
    default = re.search(r"^([ \t]*)default:[ \t]*\{[ \t]*$", src, re.M)
    if default:
        pad = default.group(1) + '  '
        block = [
            pad + "// The pack's assertions that must fail are no part of a normal run.",
            pad + "tags: process.env.CUCUMBER_TAGS || 'not @wip and not @must-fail',",
        ]
        src = src[:default.end()] + '\n' + '\n'.join(block) + src[default.end():]
        print('  cucumber.js: the tags that keep the assertions that must fail out of a normal run')

world = re.search(r"^([ \t]*)worldParameters:[ \t]*\{[ \t]*$", src, re.M)
if not world:
    sys.exit("  cucumber.js has no worldParameters block to add the users registry to.")
pad = world.group(1) + '  '
additions = []
base = "(process.env.LAUNCH_URL || '%s').replace(/\\/+$/, '')" % address
if not re.search(r"^[ \t]*mailUrl:", src, re.M):
    additions += [
        pad + "// The project's mail catcher, which the site sends its mail to.",
        pad + "mailUrl: process.env.MAIL_URL || `${%s}:8026`," % base,
    ]
if not re.search(r"^[ \t]*manager:", src, re.M):
    additions += [
        pad + "// The account that prepares and removes test content, through the site's API: the owner of the team.",
        pad + "manager: process.env.MANAGER || 'owner',",
    ]
if not re.search(r"^[ \t]*team:", src, re.M):
    additions += [
        pad + "// The team the steps work in until a scenario opens another.",
        pad + "team: process.env.TEAM || '%s'," % team,
    ]
if not re.search(r"^[ \t]*users:[ \t]*\{", src, re.M):
    rows = [r.split('|') for r in registry.splitlines() if r.strip()]
    additions += [
        pad + "// The users registry: a handle a scenario reads, mapped to an account of the site (the default accounts:",
        pad + "// cmd-tools-penpot-cli.sh --add-users). Override one with %s_<HANDLE>_EMAIL and %s_<HANDLE>_PASSWORD." % (prefix, prefix),
        pad + "users: {",
    ]
    for handle, email, password, fullname in rows:
        env = '%s_%s' % (prefix, handle.upper())
        additions.append(pad + "  %s: { email: process.env.%s_EMAIL || '%s', password: process.env.%s_PASSWORD || '%s', name: '%s' }," % (handle, env, email, env, password, fullname))
    additions.append(pad + "},")
    print('  cucumber.js: the users registry (%s)' % ', '.join(r[0] for r in rows))
if additions:
    src = src[:world.end()] + '\n' + '\n'.join(additions) + src[world.end():]
    print('  cucumber.js: the mail catcher, the managing account and the team')

# The address the suite opens when LAUNCH_URL is not set: the placeholder of the scaffold becomes the site's.
placeholder = "process.env.LAUNCH_URL || 'http://localhost:8080'"
if placeholder in src:
    src = src.replace(placeholder, "process.env.LAUNCH_URL || '%s'" % address)
    print('  cucumber.js: the address of the site (%s)' % address)

if src != before:
    open(cucumber_file, 'w').write(src)
PYEOF

  # A first feature, when the project has none for the site yet.
  local feature="${WORKSPACE_SCRIPTS}/plugins/penpot/site.feature" ;
  if [ -f "${feature}" ] && [ ! -f "${project_path}/tests/features/site.feature" ] ; then
    mkdir -p "${project_path}/tests/features" && cp "${feature}" "${project_path}/tests/features/site.feature" \
      && echo "  tests/features/site.feature: a first feature for the session" ;
  fi

  # The scenarios log in as the default accounts: make sure the site has them, once it answers again (installing the
  # webship-js add-on restarts the project, and Penpot with it).
  if ( cd "${project_path}" && penpot_wait > /dev/null 2>&1 && add_penpot_users > /dev/null 2>&1 ) ; then
    echo "  the default accounts are on the site, in ${PENPOT_TEAM} (${users[*]})" ;
  else
    echo "  The default accounts could not be written: is the site running (ddev start in ${project_path})?" ;
  fi
}
