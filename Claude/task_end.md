# Task End Instructions

1. Read dev_log_instructions.md
2. Ask for current time and location if not already provided by the user.
3. Ensure that ALL details are included in order to facilitate potential handover to a new chat context without loss of information, avoiding wasteful relearning or confusion in the new chat.
4. Make sure to document all mistakes you made AND how you corrected for them, to reduce the chance of making the same mistakes in future chats. Most important to log: - Incorrect tool usage - incorrect coding styles or project patterns - Incorrect assumptions due to failing to read in necessary source files Note that logging a mistake without also logging the corrective action is not useful - your future self needs to know what corrected action to take instead. Make you how include enough detail to avoid ambiguity and avoid repeating the mistake in future.
5. Keep in mind that you have no memory between chat contexts, so anything that you leave out will be forgotten completely. More is more.
6. Ensure that the dev log entry encompasses the ENTIRE chat session. All work done in the ENTIRE chat session needs to be documented, not just the most recent work.

## Dev Log File Handling

1. Determine the current week of year in order to know which dev log file to edit.
2. Write up the dev log entry using edit_file in the correct week file, or write_file if the week file doesn’t exist yet. If you are unsure whether the file exists yet, use read_file to check. DON’T blindly use write_file without checking first - if you do so you will clobber all existing log entries, which is BAD.
3. Remember that empty oldText strings are STRICTLY FORBIDDEN, and WILL cause fuckups in the dev log file. NEVER use edit_file with empty oldText strings.
4. Take care to insert the new log entry under the top-level header of the dev log file. 

