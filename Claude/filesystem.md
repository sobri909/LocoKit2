# Project Filesystem Organization

## Project Roots

The codebase is split across two main directories:

1. **LocoKit2** (`/Users/matt/Projects/LocoKit2/`)
   - Core library functionality
   - Timeline data model and processing
   - Sample recording and management
   - Places system
   - Actor isolation models
   - Database management

2. **Arc Timeline Editor** (`/Users/matt/Projects/Arc Timeline Editor/`)
   - SwiftUI app implementation
   - Timeline visualization
   - User interactions and state management
   - View-specific models and extensions

This separation maintains a clean divide between library functionality and app-specific code. For a complete listing of files and systems within these directories, see locokit2_manifest.md and arc_manifest.md.

## Meta Directory Organization

The Meta directory contains several key types of files:

1. **Knowledge Base** (`Meta/Knowledge/*.md`)
   - Domain-focused documentation files
   - Each file covers a specific technical area
   - Updated alongside code changes to maintain accuracy

2. **Development Logs** (`Meta/Dev Logs/dev_log_YYYY_wWW.md`)
   - Weekly logs of development work
   - Timestamped entries with implementation details
   - Maintains context of technical decisions

3. **Planning & Instructions** (Meta/*.md)
   - System-wide documentation (like this file)
   - Implementation plans for major features
   - Development workflow documentation

## Working with Files

### File Location and Access

**Step 1: Check Manifest Files First**
The manifest files (locokit2_manifest.md and arc_manifest.md) contain the complete, up-to-date mapping of all project files and their locations. Always:
1. Check appropriate manifest for file locations before using search tools
2. Use the exact paths provided in manifests
3. Only use search tools if the file's location is unclear in manifests

**Step 2: Use File Access Tools (if needed)**
If you need to find a file not clearly listed in the manifests:
1. Use `list_allowed_directories` to confirm available roots
2. Use `list_directory` to view directory contents
3. Use `search_files` only for simple filename lookups
4. Use `read_file` or `read_multiple_files` as appropriate
5. Use exact paths from the above for reading/writing

**Step 3: search_files Limitations**
`search_files` has important limitations:
- Only matches partial filenames
- Does NOT support wildcards
- Does NOT search file contents
- Does NOT support regex
- Case insensitive by default

**Step 4: Searching File Contents**
To search within file contents:
- Use `run_command` with rg (ripgrep):
```
run_command rg "search term" "/Users/matt/Projects/Arc Timeline Editor"
```
- Case insensitive search with -i flag: `rg -i "term"`
- Multiple patterns with -e: `rg -e "term1" -e "term2"`
- Searches are recursive by default and automatically skip .git directories and binary files

## File Operations

### write_file vs edit_file

Two main approaches for modifying files, each with different strengths:

1. **write_file** - Best for:
   - Small files where full content can be written efficiently
   - Files needing significant restructuring
   - Cases where you want to verify the complete file content
   - New file creation

2. **edit_file** - Best for:
   - Large files where writing full content would be token-expensive
   - Targeted changes to specific sections
   - Pattern-based replacements
   - When surrounding content should be preserved exactly

CRITICAL edit_file Requirements:

1. MOST IMPORTANT: NEVER USE EMPTY STRING FOR oldText
   - This is the single most critical rule
   - An empty oldText string will CORRUPT files
   - IT IS FORBIDDEN to use an empty string as oldText
   - Every edit_file call MUST have an anchor point in the existing file
   - To add at start of file: use file's first line as oldText
   - To add at end of file: use file's last line as oldText
   - To add in middle: use the exact text where you want to insert
   - THERE ARE NO EXCEPTIONS TO THIS RULE

2. Exact Text Matching
   - oldText must match target file EXACTLY, including ALL whitespace
   - Always use read_file first to see exact content you're replacing
   - If oldText doesn't match exactly, edit will fail
   - Copy/paste from read_file output to ensure exact match

3. Uniqueness
   - oldText must appear EXACTLY ONCE in target file
   - Multiple occurrences make edit location ambiguous
   - Use read_file to verify uniqueness before editing
   - Pick enough context to guarantee uniqueness

Example of correct edit_file usage:
```swift
// ALWAYS read file first
let content = read_file(path)

// Then edit with proper anchoring
edit_file(
    path: path,
    oldText: "# Existing Section\n",  // NEVER EMPTY STRING
    newText: "# Existing Section\n\n## New Subsection\n"
)
```

REMEMBER: Empty oldText strings are FORBIDDEN - always anchor your edits to existing file content.

Example: When adding a new dev log entry:
- BAD: oldText: "" - could match anywhere or everywhere
- GOOD: oldText: matches exact text at insertion point including newlines

Choose based on file size and change scope - write_file for small/complete changes, edit_file for large/targeted changes.

Example: When adding a new dev log entry, using write_file would accidentally overwrite all previous entries, while edit_file allows inserting the new entry while preserving the existing content. However, for a focused file like filesystem.md, write_file is appropriate when making substantial changes since writing out the complete new content is clearer and more token-efficient.

## Documentation Organization

Documentation is split between the two repositories based on visibility and scope:

### LocoKit2 (Public)
- Public API documentation
- Format specifications
- Integration guides
- Implementation-agnostic design docs
- Located in `/docs/` directory

### Arc Timeline Editor (Private)
- App-specific implementation details
- UI/UX design decisions
- Internal architecture docs
- Development processes
- Located in `Meta/` directory

Key principle: If documentation would be useful to third-party developers or external contributors, it belongs in the LocoKit2 repo. If it's specific to the Arc Editor implementation or internal development process, it stays in the Arc Editor repo.
