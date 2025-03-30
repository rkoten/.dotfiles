#!/bin/bash
# One step is 15 ms.
defaults write -g InitialKeyRepeat -int 18  # Sane minimum is 15 (225 ms).
defaults write -g KeyRepeat -int 3  # Sane minimum is 2 (30 ms).
