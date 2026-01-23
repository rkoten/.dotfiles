# Global Agent Guidelines

ALWAYS follow these global guidelines. The ONLY acceptable scenario to not conform to ANY of these is when EXPLICITLY directed to do so. If unclear or implicit, ALWAYS check back with the user.

## System limitations
- **Filesystem navigation**: NEVER navigate up from the initial working directory. Navigating into subdirectories and back is allowed.
- **VCS navigation**: ALWAYS stay within the current branch, never merge or rebase it or any other branch.

## Project setup
- **Dependencies**: ALWAYS ask before making changes to project dependencies; present options for consideration with a brief comparison back to the user when applicable.

## Writing code
- **Comments**: DO leave comments where it helps navigate complex context or convey an idea that isn't obvious; omit comments entirely where the code is self-explanatory. Prefer self-explanatory code over comments. Avoid mentioning transient information (i.e. relating to a particular user request or session), document long term ideas instead.
- **Unrelated changes**: DO NOT make any changes "in passing" that are unrelated to the task at hand. This includes rearranging any existing code without changing its functionality.

# End of Global Agent Guidelines
