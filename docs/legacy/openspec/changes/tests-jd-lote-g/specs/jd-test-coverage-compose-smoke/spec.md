# Compose Smoke Test Coverage Specification

## Purpose
Verify Compose UI navigation and accessibility basics via smoke tests.

## Requirements

### Requirement: Onboarding Start Destination
The Compose navigation graph MUST route to the correct onboarding start destination.

#### Scenario: Fresh install lands on onboarding
- GIVEN a fresh install with no onboarding completion flag
- WHEN the app launches
- THEN the start destination MUST be the onboarding screen
- AND the task list screen MUST NOT be visible

#### Scenario: Onboarding completed skips to task list
- GIVEN onboarding completion flag is set
- WHEN the app launches
- THEN the start destination MUST be the task list screen

### Requirement: Touch Target Minimum Size
All interactive Compose elements MUST meet minimum touch target size for accessibility.

#### Scenario: Button touch target compliance
- GIVEN a primary action button in any screen
- WHEN measured for touch bounds
- THEN the touch target MUST be at least 48dp × 48dp

### Requirement: String Locale Completeness
All user-facing strings MUST be present in the default locale resource files.

#### Scenario: String resource present
- GIVEN a user-facing label defined in code
- WHEN the app is compiled with the default locale
- THEN the string resource MUST resolve without fallback to raw key