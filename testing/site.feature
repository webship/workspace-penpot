Feature: The site answers, its login works and its accounts log in
  As the owner of the site
  I want the login, the dashboard and each default account to work, each in its role
  So that a build that came out broken is caught before anything else is tested

  # Placed by the workspace's testing setup as a starting point: it is yours to change.
  # The accounts are the default ones (cmd-tools-penpot-cli.sh --add-users), in the team "Design team"; a scenario
  # logs in by a handle of the users registry in cucumber.js, so no password is written here. It passes on a site
  # built with --install --add-users, with or without --sample-content: it reads only what the accounts make.

  @critical
  Scenario: A visitor is sent to the login page
    Given I am not logged in
    When I go to the homepage
    Then I should be on the login page

  Scenario Outline: The <account> account logs in through the login form
    Given I am not logged in
    When I log in as "<account>" with the login form
    Then I should be logged in as "<account>"

    Examples:
      | account |
      | owner   |
      | admin   |
      | editor  |
      | viewer  |

  Scenario: Each account is in the team in its role
    Given I am a logged in user with the "owner" user
    When I open the team "Design team"
    Then the page heading should be "Projects"
    And the member "owner" should have the role "Owner"
    And the member "admin" should have the role "Admin"
    And the member "editor" should have the role "Editor"
    And the member "viewer" should have the role "Viewer"
    Given I am a logged in user with the "viewer" user
    When I open the team "Design team"
    Then the page should not offer the button "+ New project"
    Given I am a logged in user with the "editor" user
    When I open the team "Design team"
    Then the page should offer the button "+ New project"
