# Android Native Polish Specification

## Purpose
Establish UX standards for the Android application to ensure a premium, native "feel" using Material 3 and platform-standard interactions.

## Requirements

### Requirement: Edge-to-Edge Display
The application MUST support edge-to-edge display by drawing behind system bars (status and navigation bars).

#### Scenario: Scrollable screen
- GIVEN a screen with a vertical list
- WHEN the user scrolls to the bottom
- THEN the content SHOULD be visible behind the transparent navigation bar

### Requirement: Haptic Feedback
The system SHOULD provide haptic feedback for key user interactions (task completion, deletion, long press).

#### Scenario: Task completion
- GIVEN a task in the list
- WHEN the user taps the completion checkbox
- THEN the system MUST trigger a standard "success" haptic vibration

### Requirement: Predictive Back Support
The application SHOULD support predictive back gestures to allow users to preview the previous screen.

#### Scenario: Navigating back from Detail
- GIVEN the user is on the Task Detail screen
- WHEN the user starts the back gesture
- THEN the system SHOULD show the previous list screen scaling in or sliding
