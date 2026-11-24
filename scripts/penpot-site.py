#!/usr/bin/env python3
# The Penpot test site of the step pack, made through Penpot's own API (POST /api/main/methods/<command>, JSON), as
# the accounts themselves:
#
#   python3 penpot-site.py <site address> <verb>...
#
#   props     each account's onboarding marked as seen (the questionnaire and the release notes of a new profile)
#   team      the team "Design team" and its members in their roles
#   content   the projects, the files (two of them imported from the .penpot files beside this script), a shared
#             library, a pinned project and a comment
#   tidy      what a run that was stopped half way left: projects, files and teams named "Webship test …", the files in
#             the trash, invitations to "webship-test-…" addresses, comment threads that say "Webship test"
#   list      the teams, their projects and files, and the members
#
# The accounts are made before, with the backend's own tool (penpot-accounts.py). Their password comes in the
# environment (ACCOUNT_PASSWORD) or on the input (--password-stdin), never on a command line. Each piece is looked for
# first and made only when it is not there, so a second run adds what a first one missed and changes nothing else.
import base64
import http.cookiejar
import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request
import uuid

# --password-stdin: the password comes as the base64 of the first line of the input (the plugin of the Webship
# Workspace runs this script in the backend's container so), else in ACCOUNT_PASSWORD.
PASSWORD = os.environ.get('ACCOUNT_PASSWORD', 'dD.123123ddd')
if '--password-stdin' in sys.argv:
    sys.argv.remove('--password-stdin')
    PASSWORD = base64.b64decode(sys.stdin.readline().strip()).decode()
BASE = sys.argv[1].rstrip('/')
VERBS = sys.argv[2:]
HERE = os.path.dirname(os.path.abspath(__file__))
MAIN_VERSION = os.environ.get('PENPOT_MAIN_VERSION', '')

TEAM = 'Design team'
OWNER = 'owner@example.com'
MEMBERS = [('admin@example.com', 'admin'), ('editor@example.com', 'editor'), ('viewer@example.com', 'viewer')]
ACCOUNTS = [OWNER] + [m for m, _ in MEMBERS]

CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE


class Session:
    """One account's session on the site: its cookie, and the API called as it."""

    def __init__(self, email):
        self.email = email
        self.jar = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(self.jar),
                                                  urllib.request.HTTPSHandler(context=CTX))

    def _open(self, req, what, tries=4):
        for attempt in range(tries):
            try:
                with self.opener.open(req, timeout=120) as r:
                    return r.read().decode()
            except urllib.error.HTTPError as e:
                body = e.read().decode()[:400]
                # The backend answers 429 or 503 while it is busy or starting: a moment later it does.
                if e.code in (429, 502, 503, 504) and attempt < tries - 1:
                    time.sleep(3 * (attempt + 1))
                    continue
                raise RuntimeError(f'{what} as {self.email}: {e.code} {body}')
            except urllib.error.URLError as e:
                if attempt < tries - 1:
                    time.sleep(3 * (attempt + 1))
                    continue
                raise RuntimeError(f'{what} as {self.email}: {e}')

    def call(self, cmd, params=None):
        req = urllib.request.Request(f'{BASE}/api/main/methods/{cmd}', data=json.dumps(params or {}).encode(),
                                     headers={'Content-Type': 'application/json', 'Accept': 'application/json'})
        body = self._open(req, cmd)
        if not body.strip():
            return None
        try:
            return json.loads(body)
        except ValueError:
            # A command that streams its progress (events, not JSON) has done its work once the stream ends.
            return body

    def login(self):
        self.profile = self.call('login-with-password', {'email': self.email, 'password': PASSWORD})
        return self

    def import_file(self, project_id, name, path):
        """A .penpot file into a project: multipart, the answer a stream of events, the last one the result."""
        boundary = uuid.uuid4().hex
        parts = []
        # The version is read from the file itself: a form field could only send it as text, which the API refuses.
        for key, value in (('name', name), ('project-id', project_id)):
            parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode())
        with open(path, 'rb') as f:
            data = f.read()
        parts.append((f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{os.path.basename(path)}"\r\n'
                      'Content-Type: application/zip\r\n\r\n').encode() + data + b'\r\n')
        parts.append(f'--{boundary}--\r\n'.encode())
        req = urllib.request.Request(f'{BASE}/api/main/methods/import-binfile', data=b''.join(parts),
                                     headers={'Content-Type': f'multipart/form-data; boundary={boundary}',
                                              'Accept': 'text/event-stream'})
        body = self._open(req, f'import-binfile {name}')
        if 'event: error' in body:
            raise RuntimeError(f'import-binfile {name}: {body[-400:]}')
        return body


def sessions():
    return {email: Session(email).login() for email in ACCOUNTS}


def live_projects(s, team_id):
    # A deleted project stays in the answer for a week, with the date it goes: it is not there any more.
    return [p for p in s.call('get-projects', {'teamId': team_id}) if not p.get('deletedAt')]


def team_of(owner):
    return next((t for t in owner.call('get-teams') if t.get('name') == TEAM), None)


# The account whose questionnaire stays unanswered: the suite walks it (answers sent once stay on an account for good).
QUESTIONNAIRE_ACCOUNT = 'admin@example.com'


def verb_props():
    # The onboarding of a new profile (its questionnaire, then the choice of a team) and the release notes of this
    # version: seen, so a test opens the dashboard. Every account but one has answered the questionnaire, so the
    # onboarding they meet again (a scenario turns it on) is the choice of a team.
    for email in ACCOUNTS:
        s = Session(email).login()
        props = {'onboarding-viewed': True}
        if MAIN_VERSION:
            props['release-notes-viewed'] = MAIN_VERSION
        if email != QUESTIONNAIRE_ACCOUNT and 'onboardingQuestions' not in (s.profile or {}).get('props', {}):
            props['onboarding-questions'] = {'expected-use': 'work'}
            props['onboarding-questions-answered'] = True
        s.call('update-profile-props', {'props': props})
        print(f'Account {email}: onboarding seen')


def verb_team():
    owner = Session(OWNER).login()
    team = team_of(owner)
    if not team:
        team = owner.call('create-team', {'name': TEAM})
        print(f'Team {TEAM}')
    members = {m.get('email'): m for m in owner.call('get-team-members', {'teamId': team['id']})}
    for email, role in MEMBERS:
        member = members.get(email)
        if not member:
            # A profile that is there already joins at once; another would take the invitation's token.
            owner.call('create-team-invitations', {'teamId': team['id'], 'emails': [email], 'role': role})
            now = {m.get('email'): m for m in owner.call('get-team-members', {'teamId': team['id']})}
            if email not in now:
                token = owner.call('get-team-invitation-token', {'teamId': team['id'], 'email': email})
                Session(email).login().call('verify-token', {'token': token})
            print(f'Member {email}: {role}')
            continue
        current = 'admin' if member.get('isAdmin') else ('editor' if member.get('canEdit') else 'viewer')
        if current != role and not member.get('isOwner'):
            owner.call('update-team-member-role', {'teamId': team['id'], 'memberId': member['id'], 'role': role})
            print(f'Member {email}: {role} again')


def project_files(s, project_id):
    return {f['name']: f for f in s.call('get-project-files', {'projectId': project_id})}


def verb_content():
    owner = Session(OWNER).login()
    editor = Session('editor@example.com').login()
    team = team_of(owner)
    if not team:
        sys.exit(f'No team "{TEAM}": run the verb team first.')
    projects = {p['name']: p for p in live_projects(owner, team['id'])}

    def project(name, pinned=False):
        if name not in projects:
            projects[name] = owner.call('create-project', {'teamId': team['id'], 'name': name})
            print(f'Project {name}')
        if pinned and not projects[name].get('isPinned'):
            owner.call('update-project-pin', {'teamId': team['id'], 'id': projects[name]['id'], 'isPinned': True})
        return projects[name]

    website = project('Website redesign', pinned=True)
    brand = project('Brand')
    drafts = next(p for p in live_projects(owner, team['id']) if p.get('isDefault'))

    files = project_files(owner, website['id'])
    if 'Homepage' not in files:
        owner.import_file(website['id'], 'Homepage', os.path.join(HERE, 'homepage.penpot'))
        print('File Homepage (the boards Hero, with its Button, and Footer)')
    if 'Pricing page' not in files:
        owner.call('create-file', {'projectId': website['id'], 'name': 'Pricing page'})
        print('File Pricing page')
    files = project_files(owner, brand['id'])
    if 'Style guide' not in files:
        owner.import_file(brand['id'], 'Style guide', os.path.join(HERE, 'style-guide.penpot'))
        print('File Style guide (the component Logo)')
        files = project_files(owner, brand['id'])
    if not files['Style guide'].get('isShared'):
        owner.call('set-file-shared', {'id': files['Style guide']['id'], 'isShared': True})
        print('Style guide: a shared library')
    if 'Sketches' not in project_files(owner, drafts['id']):
        owner.call('create-file', {'projectId': drafts['id'], 'name': 'Sketches'})
        print('Draft Sketches')

    # A comment of the editor on the homepage, on its board Hero.
    homepage = project_files(owner, website['id'])['Homepage']
    threads = editor.call('get-comment-threads', {'fileId': homepage['id']})
    if not any((t.get('content') or '').startswith('Can the hero be taller?') for t in threads):
        data = owner.call('get-file', {'id': homepage['id']})
        pages = data['data']['pages']
        page_id = pages[0]
        objects = data['data']['pagesIndex'][page_id]['objects']
        hero = next(o for o in objects.values() if o.get('name') == 'Hero')
        editor.call('create-comment-thread', {'fileId': homepage['id'], 'pageId': page_id, 'frameId': hero['id'],
                                              'position': {'x': hero['x'] + 20, 'y': hero['y'] + 20},
                                              'content': 'Can the hero be taller?'})
        print('Comment of the editor on Homepage')


def verb_tidy():
    removed = 0
    owner = Session(OWNER).login()
    for team in owner.call('get-teams'):
        if team.get('name', '').startswith('Webship test'):
            owner.call('delete-team', {'id': team['id']})
            removed += 1
            continue
        for project in live_projects(owner, team['id']):
            if project.get('name', '').startswith('Webship test'):
                owner.call('delete-project', {'id': project['id']})
                removed += 1
                continue
            for f in owner.call('get-project-files', {'projectId': project['id']}):
                if f.get('name', '').startswith('Webship test'):
                    owner.call('delete-file', {'id': f['id']})
                    removed += 1
                    continue
                for t in owner.call('get-comment-threads', {'fileId': f['id']}):
                    if 'Webship test' in (t.get('content') or ''):
                        owner.call('delete-comment-thread', {'id': t['id']})
                        removed += 1
        if not team.get('isDefault'):
            for inv in owner.call('get-team-invitations', {'teamId': team['id']}):
                if inv.get('email', '').startswith('webship-test'):
                    owner.call('delete-team-invitation', {'teamId': team['id'], 'email': inv['email']})
                    removed += 1
        # What a scenario deleted is in the trash: gone for good, so a next run starts from the same site.
        # (A file given to the trash's own deletion already goes within the minute: it is not asked for again.)
        soon = time.strftime('%Y-%m-%dT%H:%M:%S', time.gmtime(time.time() + 120))
        deleted = [d for d in owner.call('get-team-deleted-files', {'teamId': team['id']})
                   if (d.get('willBeDeletedAt') or '9999') > soon]
        if deleted:
            owner.call('permanently-delete-team-files', {'teamId': team['id'], 'ids': [d['id'] for d in deleted]})
            removed += len(deleted)
    # The other accounts' own drafts and teams that a scenario made.
    for email, _ in MEMBERS:
        s = Session(email).login()
        for team in s.call('get-teams'):
            if team.get('name', '').startswith('Webship test') and team.get('isOwner', team.get('role') == 'owner'):
                s.call('delete-team', {'id': team['id']})
                removed += 1
    print(f'Removed {removed} piece(s) of test content.')


def verb_list():
    owner = Session(OWNER).login()
    for team in owner.call('get-teams'):
        print(f'Team {team["name"]}')
        if not team.get('isDefault'):
            for m in owner.call('get-team-members', {'teamId': team['id']}):
                role = 'owner' if m.get('isOwner') else 'admin' if m.get('isAdmin') else 'editor' if m.get('canEdit') else 'viewer'
                print(f'  member {m.get("email")}: {role}')
        for p in live_projects(owner, team['id']):
            names = [f['name'] for f in owner.call('get-project-files', {'projectId': p['id']})]
            print(f'  project {p["name"]}: {", ".join(names) or "(no file)"}')


for verb in VERBS:
    {'props': verb_props, 'team': verb_team, 'content': verb_content, 'tidy': verb_tidy, 'list': verb_list}[verb]()
