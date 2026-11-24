---
name: penpot-scenarios
description: Write webship-js scenarios for a Penpot site (the open-source design and prototyping platform) of the Webship Workspace from phrases that exist — the Penpot step pack's steps by area (the session and the onboarding, the dashboard and its projects and files, the team's members and invitations, the workspace's pages, tools, layers and values, assets and libraries, inspect, tokens, history, comments, the view mode and its share link, exports, the account, the mail, test content), the traps found on real sites, and three whole features. Use when asked to write, extend or fix scenarios for a Penpot site, or when a scenario of the site fails on a phrase.
---

# penpot-scenarios

Scenarios for a site built with the Penpot plugin (`bash cmd-penpot-project.sh <site> --install --add-users`;
`--sample-content` for the projects, files and comment the pack is tested on) in a container-based workspace (DDEV
by default), tested with webship-js and `@webship-js/penpot-steps` once `bash cmd-tools-testing.sh <site>` set the
project up. Every phrase below exists in the pack or in webship-js; a scenario names no platform.

## Accounts

- `Given I am a logged in user with the "editor" user`: `owner` (owns the team "Design team"), `admin` (the members
  and their invitations), `editor` (the projects and the files), `viewer` (reads, comments, inspects). `Given I am not
  logged in` for a visitor.
- The accounts are made by the build (`cmd-tools-penpot-cli.sh <site> --add-users`); a suite never creates or deletes
  one, and never writes a password: it logs in by the handle.

## Phrases by area

| Area | Steps |
| --- | --- |
| Session | `I log in as "editor" with the login form`, `I log in with the email "…" and the password "…"`, `the login should be refused with "Email or password is incorrect."`, `I am not logged in`, `I log out`, `I should be logged in`, `I should not be logged in`, `I should be logged in as "editor"`, `I should be on the login page` (`… saying "…"`), `I should be on the registration page`, `I ask for a password reset link for "editor"`, `I set the password of "editor" on the reset page`, `I try to register with the name "…", the email "…" and the password "…"`, `the registration should be refused with "Email already used"` |
| Onboarding | `"admin" has not done the onboarding yet`, `the onboarding should ask "Help us get to know you"`, `I choose "Personal" in the onboarding`, `I answer "…" in the box "Other (specify)" of the onboarding`, `I press "Next" in the onboarding`, `the button "Start" of the onboarding should be enabled`, `the onboarding should be over` |
| Dashboard | `I open the team "Design team"`, `I go to "Drafts" in the dashboard`, `the page heading should be "Projects"`, `the dashboard should show the project "…"` (`should not show`), `the project "…" should list the file "…"`, `I create the project "…"`, `I rename the project "…" to "…"`, `I open the options of the project "…"`, `I right-click the file "…"`, `the menu should offer "Rename"` (`should not offer`), `I choose "Move to" in the menu`, `I close the menu`, `I choose "Delete" in the options of the file "…"`, `the options of the project "Drafts" should not offer "Delete"`, `I create a file in the project "…"`, `I open the file "…" from the dashboard`, `I rename the file "…" to "…"`, `I select the files "…" and "…"`, `I right-click the selected file "…"`, `I search the dashboard for "…"`, `the page should list the file "…"`, `the trash should list the file "…"`, `the pinned projects should list "…"`, `the page should offer the button "+ New project"` |
| The site's answers | `the site should say "Your file has been deleted successfully"`, `the site should ask "Are you sure you want to delete this file?"`, `I press "Delete file" in the dialog`, `the dialog should say "…"`, `the button "Export" of the dialog should be disabled`, `I close the dialog`, `no dialog should be open` |
| Team | `I create the team "…"`, `the team switch should list "…"`, `I choose "Delete team" in the team options`, `the team options should not offer "Invitations"`, `the member "editor" should have the role "Editor"`, `the role of the member "owner" should not be changeable`, `I change the role of the member "viewer" to "Editor"`, `I invite "webship-test-…@example.com" to the team as "Viewer"`, `I start an invitation to "editor"`, `I add "…" to the invitation`, `the invitations should list "…" as "Pending"`, `I select the invitation to "…"`, `I delete the invitation to "…"` |
| Workspace | `I open the file "Homepage"` (`… at a page that does not exist`), `the open page should be "Page 1"`, `the pages should list "…"`, `I add a page`, `I open the page "…"`, `I rename the page "…" to "…"`, `I draw a "Board" on the canvas`, `I draw a "Rectangle" in the board "…"` (an `"Ellipse"`), `I write the text "…" in the board "…"` (`on the canvas`), `I draw a path on the canvas`, `the layers should list "…"`, `the layer "…" should be selected`, `I select the layer "…"`, `I add the layer "…" to the selection`, `I rename the layer "…" to "…"`, `I delete the layer "…"`, `I group the selection`, `I make the selection a component`, `the layer "…" should be a component` (`a variant`), `I undo the last change`, `the design value "Width" should be "300"` (`"Mixed"`), `I set the design value "Rotation" to "45"`, `the selection should measure "300 x 200"`, `I add a "stroke" to the selection`, `the main menu "File" should offer "…"`, `I choose "Hide comments" in the main menu "View"`, `the workspace should show the drawing tools`, `I open the "Inspect" tab`, `the side panel should offer the tab "Design"` |
| Assets and libraries | `the assets should list the component "Logo"`, `the assets should show "Local library"`, `I connect the library "Style guide"`, `I disconnect the library "…"` |
| Inspect, tokens, history | `the inspect panel "Fill" should show "Background" as "#B1B2B5 100%"`, `I switch the inspect panel to "Code"`, `the inspect code should contain "width: 120px;"`, `I create a "Color" token "…" with the value "#ff0000"`, `I try to create a "Color" token "…" with the value "1"`, `the tokens should list "…"`, `the token set "Global" should be active`, `I apply the token "…" to the selection as "Fill"`, `the token "…" should be applied to the "Fill"`, `I save a version named "…"`, `the history should list the version "…"`, `I restore the version "…"` |
| Comments and others in the file | `I add the comment "…" on the board "…"`, `the comments should list "…"`, `I close the comments panel`, `the page should show 2 comment bubbles`, `"owner" has the file "…" open`, `the file should show "owner" among its users`, `"owner" closes the file` |
| View mode | `I open the view mode`, `the view mode should show the board "Footer"`, `the view mode should show the board 1 of 2`, `I go to the next board`, `I set the zoom of the view mode to "Fit"`, `I open the "Comments" section of the view mode`, `I add an export in the view mode`, `I create a share link`, `a visitor should see the file "…" with the share link`, `I destroy the share link`, `I go back to the dashboard from the view mode` |
| Exports | `I press "Export" in the dialog to download a file`, `I press the button "Export 1 element" to download a file`, `I download the open file`, `the downloaded file should be a PDF of 1 page`, `the downloaded file should be a PNG image of 300 by 200 pixels`, `the downloaded file name should be "…"` (webship-js) |
| Account | `I open the profile menu`, `I point at "Help & Learning" in the profile menu`, `I choose "Version" in the profile menu`, `the profile menu should offer "Help Center"`, `the release notes should show "…"`, `I read the release notes to the end`, `I go to "Settings" in my account`, `the setting "UI theme" should be "…"`, `I search the shortcuts for "…"`, `the shortcuts should list "…"` |
| Mail | `an email with the subject "Password reset" should have been sent to "editor"`, `the email with the subject "…" to "…" should say "…"`, `I open the link of the email with the subject "…" to "…"` |
| Test content | `there is no project "…"` (`… in the team "…"`), `there is a project "…"`, `there is no file "…"`, `there is a new file "…" in the project "…"`, `there is no team "…"`, `there is no invitation to "…"`, `there is no comment that says "…" on the file "…"` |

## Traps found on real sites

- **Messages go after a few seconds.** `the site should say "…"` reads them anyway: the pack records each message as
  it comes. Check it right after the action that brings it.
- **The panel "Libraries & Templates"** lies over the bottom of the dashboard and takes the clicks meant for the
  cards below it: the pack's steps fold it first, as a person does.
- **A menu left open takes the next click** to close itself: `I close the menu` before another action.
- **The layers of a parent are folded** until it is opened: the pack's steps open them before they look.
- **Escape on the canvas drops the selection**: select the layer again before a step that works on it.
- **The comments mode shows the bubbles whatever the View menu says**: `I close the comments panel` before
  `Hide comments`.
- **The workspace's "Share" invites people; the view mode's "Share" makes a link.**
- **A version is restored from a bar at the top** that asks first; the pack's step answers it.
- **The questionnaire of a new account**, once its answers are sent with "Start", never comes back for that account:
  walk it without sending it (the build leaves `admin` with it unanswered).
- **A refusal is an error status**: the browser logs "Failed to load resource" for a 400; give those scenarios
  `@js-off`.

## Three whole features

They pass on a site built with `--install --add-users --sample-content`:

- [`examples/session-and-roles.feature`](examples/session-and-roles.feature): the login, a refusal, what a viewer does not get.
- [`examples/workspace-and-inspect.feature`](examples/workspace-and-inspect.feature): a board and a rectangle drawn, their values, the Inspect tab.
- [`examples/view-mode-and-export.feature`](examples/view-mode-and-export.feature): the boards of the view mode, a share link, the PDF export.

Copy them into `tests/features/` of a project built with `--sample-content` and run them:

```bash
bash cmd-tools-testing.sh <site> --run --path tests/features/workspace-and-inspect.feature
```

## The book

For any automated functional testing in this work (a Gherkin feature, a step definition, choosing a
step, a test run and its failures), read the book *Automated Functional Testing Recipes* first.

- **Where.** Use the first that exists: `.claude/automated-functional-testing-recipes/` in the project,
  `~/.claude/automated-functional-testing-recipes/` (installed by webship/webship-js-ai-agent,
  webship/webship-js-skills or webship/ai-agents), or
  https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes
- **How.** Its `README.md` first, then the chapter that matches the task (one file per chapter,
  named by its subject), not the single complete file.
- **Which wins.** The installed webship-js package and the step pack are the source of truth for
  step phrasing. When they differ from the book, follow them and say so.
- **For a site.** Start with `ch10-authentication-authorization.md` (logins, refusals and what each role may do),
  `ch07-waiting-dynamic-content.md` (waiting on the app's own signals) and `ch26-testing-cms-applications.md`
  (content made and removed, roles, a workflow across roles).
