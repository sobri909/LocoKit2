# Private Beta Release Notes Guide

## Core Principles

### Audience Understanding
- Private beta testers are highly technical and detail-oriented
- They care about implementation details but not internal code structure
- They expect precise, accurate descriptions of changes
- They will discuss changes and raise questions about imprecise wording

### Content Requirements

1. Timing & Versioning
   - Include full version and build number
   - Include timestamp with timezone and location
   - Organize in reverse chronological order
   - Place latest build at top of file

2. Language Requirements
   - Use precise technical terms
   - Avoid subjective assessments (e.g., "major", "significant")
   - State exact behaviors rather than general descriptions
   - Be explicit about causality when known
   - Never downplay issues (e.g., say "untappable" not "hard to tap")

3. Content Organization
   - Use consistent heading levels (### for sections)
   - Primary categorization: separate fixes from new additions/features
   - Common sections: "Bug Fixes", but others will vary based on release content
   - Group related changes together within sections
   - Put all changes under appropriate section headers

### What to Include

1. Bug Fixes
   - Actual behavior that was fixed
   - Cause if relevant to users (e.g., "caused by attempted photo loading")
   - Impact on user experience
   - Specific scenarios or contexts where issues occurred

2. Additional Changes
   - New features or improvements
   - Added debugging capabilities
   - Infrastructure improvements that impact testing

### What to Exclude

1. Implementation Details
   - Internal code structure changes
   - Technical debt cleanup
   - Refactoring work
   - File or class names

2. Internal Processes
   - Development workflow changes
   - Build system modifications
   - Internal tools updates

## Writing Guidelines

### Style Examples

Good:
- "Fixed untappable buttons in debug views through custom nav bar implementation"
  * Precise description of the bug ("untappable")
  * Clear location ("debug views")
  * Implementation mentioned when relevant to testers

Bad:
- "Fixed hard-to-tap buttons through consistent navigation improvements"
  * Imprecise description ("hard-to-tap")
  * Vague implementation detail ("consistent navigation")
  * Missing specific context

### Format

```markdown
## 1.0 (build X), YYYY-MM-DD HH:MM (Location)

### Bug Fixes
- Fixed [specific issue] in [specific context]
- Fixed [behavior] caused by [relevant cause]

### Additional Changes
- Added [new capability]
- Updated [relevant component]
```

## Release Process

1. Build Preparation
   - Review dev logs since last release
   - Filter changes to only those since previous build timestamp
   - Identify user-facing changes and fixes
   - Draft notes focusing on tester-relevant details

2. Review Process
   - Verify precise wording of each line item
   - Check that technical details are accurate
   - Ensure consistent formatting
   - Remove any unnecessary implementation details

3. Documentation Update
   - Add new release notes at top of file
   - Maintain consistent section styling
   - Preserve existing entries
   - Update timestamp with current time and location