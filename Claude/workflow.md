# Development Workflow

## Technical Standards

1. Swift Architecture
   - Swift 6 modern concurrency patterns
   - Pure SwiftUI with @Observable for Arc Editor
   - async/await and actors, no DispatchQueues
   - Maintain clean library/app separation

2. Architecture Requirements
   - Strong actor isolation boundaries
   - Proper background state handling
   - Established error handling patterns
   - App-layer UI state management
   - Clear architectural layering

3. File Organization
   - Follow existing module boundaries
   - Maintain library/app separation
   - Keep consistent naming patterns
   - Use established extension patterns

## Required Reading

Before starting any development work:
1. Read filesystem.md for critical file access patterns and limitations
2. Review locokit2_manifest.md and arc_manifest.md for project structure and key file locations
3. Review knowledge base files relevant to your task
4. Check recent dev logs for context

## Collaborative Development Approach

This codebase supports a production application with thousands of users and requires careful, incremental development:

1. Incremental Changes Only
   - Make small, focused changes rather than large-scale rewrites
   - Submit only a few changes at a time for review
   - Avoid the temptation to "fix everything at once"
   - Break complex tasks into smaller units of work

2. Collaborative Decision Making
   - Discuss architectural changes before implementing them
   - Ask questions when uncertain about design patterns
   - Wait for guidance on complex or far-reaching changes
   - Treat development as pair programming, not solo work

3. Context Awareness
   - Remember this is a mobile app with strict energy/performance requirements
   - Consider background operations, battery impact, and memory usage
   - Respect established patterns rather than introducing new ones
   - Understand that seemingly minor changes can have major impacts

4. Development Process
   - Start with understanding before coding
   - Propose specific, limited changes
   - Implement only after discussion and agreement
   - Review together before moving to the next change

This approach may seem slower initially but produces more robust, maintainable code and prevents costly rework and debugging sessions.

## Development Process

1. Task Setup
   - Review locokit2_manifest.md and arc_manifest.md to identify relevant systems and files
   - Load necessary source files using documented file access patterns from filesystem.md
   - Reference knowledge files for patterns and context
   - Consider cross-system implications
   - Ask for help with any requirements not covered by documentation
   - Be explicit about uncertainties in understanding

2. Implementation Approach
   - Focus on one task at a time
   - Think through full implications
   - Consider both library and app impact
   - Follow existing patterns
   - Request additional context if needed
   - Load related source files as dependencies become clear

3. Knowledge Management
   - Keep knowledge base files current
   - Document decisions in Meta/Dev Logs
   - Track uncertainties explicitly
   - Maintain clear rationales
   - Update docs based on implementation learnings
   - Place public-facing docs in LocoKit2 repo
   - Keep implementation details in Arc Editor repo
   - Consider third-party developer needs when choosing doc location

4. Code Organization
   - Follow structure documented in appropriate manifest file
   - Keep imports clean and focused
   - Maintain clear responsibility boundaries
   - Ensure new files are added to appropriate manifest

## Code Comment Styling

1. Internal Comments
   - Use lowercase for all regular code comments (explanatory, todo, etc.)
   - Do not capitalize sentences in internal comments
   - Capitalize only proper keywords (e.g., Swift types like Array, List, Dictionary)
   - Capitalize class/struct/enum names (e.g., ActivityType, Place, TimelineItem)
   - Example: `// this function handles the ActivityType classification process`

2. Special Comments
   - Keep Xcode-specific comment markers in caps: `// MARK:`, `// TODO:`, `// FIXME:`
   - Use title case for MARK section descriptions: `// MARK: - Task Handler Implementation`
   - These special comments power Xcode's navigation features and should stand out

3. Documentation Comments
   - Use proper sentence capitalization for doc comments (i.e., comments with `///` or `/** */`)
   - These appear as public documentation and should follow standard writing conventions
   - Example: `/// Returns the distance between two coordinates in meters.`

4. Comment Purpose and Content
   - Focus EXCLUSIVELY on "why" not "what" in internal comments
   - NEVER write comments that merely describe what the code is doing - this actively damages code quality
   - Comments that restate the obvious (e.g., "// update the place") are harmful, not helpful
   - Redundant comments create maintenance burdens and cognitive noise
   - "What" explanations are only permissible when the code is extremely complex or uses unintuitive patterns
   - Good: `// early return for performance with large datasets`
   - Bad: `// call frobble on the bob`
   - Terrible: `// log which place we're updating` before a logging statement

   If you find yourself writing a comment that just describes what the line does, DELETE THE COMMENT IMMEDIATELY.
   
   Remember: Every comment is a potential liability that must be maintained alongside code changes.

5. Logging Best Practices
   - Use logger.error() for error conditions: `logger.error(error, subsystem: .tasks)`
   - Use logger.info() for general information: `logger.info("Process started", subsystem: .tasks)`
   - Always include the relevant subsystem enum value
   - Unlike internal comments, log messages should use proper sentence capitalization

The key principle: internal code comments use lowercase for ordinary words to maintain clear visual distinction between common language and actual code entities (types, classes, etc). This prevents ambiguity when referring to things that might be both everyday terms and specific Swift types (e.g., list vs List, array vs Array).

## Communication Standards  

- Use New Zealand English spellings
- Communicate certainty levels clearly
- Don't apologize for normal development iteration
- Don't suggest tests/logging unless specifically relevant
- When confidence is low, prefer collaborative brainstorming over hasty code
- Be explicit about confidence levels - high confidence in wrong code is worse than acknowledged uncertainty

## File Access

IMPORTANT: Before using any file-related functions (read_file, search_files, etc), you MUST read filesystem.md for critical instructions on file access patterns and limitations. Incorrect usage of these functions will lead to inefficient operations and incorrect results. In particular:
- search_files only matches filenames, not content
- Use run_command with rg (ripgrep) for searching file contents
- Always verify paths exist before attempting access
- Follow documented patterns for different file operations

## Source Context Guidelines

When starting new tasks:

1. Required Context
   - Core files being modified (referenced from appropriate manifest)
   - Related files for understanding patterns
   - Relevant knowledge base sections
   - Recent dev log entries if continuing work

2. Additional Context
   - Examples of similar patterns elsewhere
   - Related UI components and their structure
   - Database schema for data changes
   - Actor isolation boundaries being crossed

3. Ongoing Work
   - Request more context if uncertainties emerge
   - Note which files seem to be missing
   - Be explicit about assumptions
   - Document new patterns discovered
   - Keep manifests updated as file structure evolves
