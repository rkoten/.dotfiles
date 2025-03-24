#!/bin/bash
# One step is 15 ms.
defaults write -g InitialKeyRepeat -int 16  # Sane minimum is 15 (225 ms).
defaults write -g KeyRepeat -int 2  # Sane minimum is 2 (30 ms).
