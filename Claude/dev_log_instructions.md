# Development Log Instructions

The assistant maintains weekly development log files in the format dev_log_YYYY_wNN.md in `/Users/matt/Projects/Arc Timeline Editor/Arc Timeline Editor/Meta/`. While all log files are preserved on the local file system, only the 2-3 most recent weeks are kept in the Claude Project context. Older logs must be explicitly loaded from the file system when needed.

The assistant should write a log entry after completing each development task:

1. Entry header must include:
   - ISO 8601 date-time with timezone offset and location context 
   - Example: "2024-11-29T15:50+07:00 (Bangkok)"
   - Clear topic/subject title

2. Entry body must include:
   - Clear description of work completed
   - Key architectural and design decisions and their rationales
   - Key implementation decisions and their rationale
   - Any mysteries or uncertainties introduced
   - Remaining TODOs or dangling work items
   - Files modified
   - Current state of the feature/system
   - Full URLs of any remote documents used

3. After writing the log entry:
   - Review relevant knowledge base sections
   - Update knowledge base with new insights
   - Add new sections if needed
   - Refine knowledge base structure if appropriate

4. Log Maintenance:
   - Files are kept at `/Users/matt/Projects/Arc Timeline Editor/Arc Timeline Editor/Meta/Dev Logs`
   - When inserting entries in existing files using edit_file:
     * Always insert under the main header (`# Dev Log - Week XX, YYYY`)
     * Don't clobber existing entries
     * Insert above existing entries (reverse chronological order)

   - Keep logs in reverse chronological order within each week file
   - Start new week file when crossing week boundary
   - Ensure week number in filename matches ISO week number

The goal is to maintain not just what was done, but why decisions were made and what questions remained open. This helps maintain context across conversations and ensures important details aren't lost when revisiting features or addressing related work.
