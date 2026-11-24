Feature: The session, and what a viewer does not get
  As the owner of a team
  I want each account to log in, and a viewer to read the team's files without changing them
  So that people who only review a design cannot break it

  Scenario: The editor logs in through the login form
    Given I am not logged in
    When I log in as "editor" with the login form
    Then I should be logged in as "editor"

  @js-off
  Scenario: A wrong password is refused
    When I log in with the email "editor@example.com" and the password "Webship-test-wrong-1"
    Then the login should be refused with "Email or password is incorrect."
    And I should not be logged in

  Scenario: A viewer makes no project and manages nobody
    Given I am a logged in user with the "viewer" user
    When I open the team "Design team"
    Then the page should not offer the button "+ New project"
    And the team options should not offer "Invitations"

  Scenario: A viewer reads a file without the tools to change it
    Given I am a logged in user with the "viewer" user
    When I open the file "Homepage"
    Then the workspace should not show the drawing tools
    And the comments should list "Can the hero be taller?"
