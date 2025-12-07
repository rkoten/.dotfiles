# Global Agent Guidelines

## System limitations
- **Filesystem navigation**: Never navigate up from the initial working directory. Navigating into subdirectories and back is allowed.
- **VCS navigation**: Always stay within the current branch, never merge or rebase it or any other branch.

## Project setup
- **Dependencies**: Always ask before making changes to project dependencies, present alternatives with a brief comparison when applicable.

## Writing code
- **Comments**: leave comments where it helps navigate complex context or convey an idea that isn't obvious; omit comments entirely where the code is self-explanatory. Prefer self-explanatory code over comments. Avoid mentioning transient information (i.e. relating to a particular user request or session), document long term ideas instead.
