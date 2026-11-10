# Edge-to-Edge Display Specification

## Purpose
Ensure the application content spans the full screen, including behind system bars, following Android 15+ standards.

## Requirements

### Requirement: Drawing Behind System Bars
The application MUST draw its content behind the status bar and navigation bar.

#### Scenario: Full Screen Coverage
- GIVEN the application is running on Android 15
- WHEN the app starts
- THEN the content SHALL extend from the very top to the very bottom of the display.

### Requirement: Inset Handling
The application MUST use Window Insets to ensure interactive elements are not obscured by system UI or cutouts.

#### Scenario: Bottom Bar Padding
- GIVEN the app is in edge-to-edge mode
- WHEN the Bottom Navigation Bar is displayed
- THEN it MUST include padding for the system navigation bar (gesture pill or 3-button nav).
