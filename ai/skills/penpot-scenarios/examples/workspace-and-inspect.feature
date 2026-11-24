Feature: A board and a rectangle, their values and their Inspect panels
  As a designer of a team
  I want to draw and size shapes, and read them as a developer does
  So that what is designed is what is built

  Background:
    Given there is a new file "Webship test file" in the project "Webship test project"
    And I am a logged in user with the "editor" user
    And I open the file "Webship test file"

  Scenario: A board sized, a rectangle in it with a stroke, read in the Inspect tab
    When I draw a "Board" on the canvas
    And I set the design value "Width" to "300"
    And I set the design value "Height" to "200"
    Then the selection should measure "300 x 200"
    When I draw a "Rectangle" in the board "Board"
    And I set the design value "Width" to "120"
    And I add a "stroke" to the selection
    And I open the "Inspect" tab
    Then the inspect panel "Size and position" should show "Width" as "120px"
    And the inspect panel "Stroke" should show "Border width" as "1px"
