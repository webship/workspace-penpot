Feature: The view mode, its share link and the PDF export
  As a member of a team
  I want to go through the boards of a file, share them with a link and export them
  So that people review a design where they are

  Scenario: The boards one after another
    Given I am a logged in user with the "owner" user
    When I open the file "Homepage"
    And I open the view mode
    Then the view mode should show the board 1 of 2
    When I go to the next board
    Then the view mode should show the board "Hero"

  Scenario: A share link a visitor uses until it is destroyed
    Given I am a logged in user with the "owner" user
    When I open the file "Homepage"
    And I open the view mode
    And I create a share link
    Then a visitor should see the file "Homepage" with the share link
    When I destroy the share link
    Then a visitor should not see the file "Homepage" with the share link

  Scenario: The selected board exported as a PDF
    Given I am a logged in user with the "owner" user
    When I open the file "Homepage"
    And I select the layer "Hero"
    And I choose "Export boards as PDF" in the main menu "File"
    Then the dialog should say "1 of 1 elements selected"
    When I press "Export" in the dialog to download a file
    Then the downloaded file should be a PDF of 1 page
