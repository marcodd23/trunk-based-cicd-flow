#!/bin/bash
#
# Validates a text against a sub-set of the Conventional Commits
# specification https://www.conventionalcommits.org
#
# The text could be for example a commit message or PR title.
#
# Supported features
#  - list of commit types
#  - optional scope
#  - breaking changes are declared using the ! character in the commit subject
#
# Example of valid text
#  - feat: add something
#  - fix(docs): typo in README
#  - feat(api)!: change the parameter order in the api
#  - fix(api): fixed broken import (#123)
#
# Example of invalid text
#  - did some work
#  - feat:add support for something
#  - hack: did my own thing
#  - FEAT: A COOL NEW FEATURE
#

# Define the list of supported text types.
SUPPORTED_TYPES="build|ci|chore|docs|feat|fix|perf|refactor|style|test"

# Define the valid text format regex.
VALID_TEXT_FORMAT="^($SUPPORTED_TYPES)(\([a-z]+\))?!?: [a-zA-Z0-9\`~<>\., \/_@()#&-]+$"

# Validate text.
if ! [[ "$1" =~ $VALID_TEXT_FORMAT ]]; then
    printf "❌ Invalid text format: \"%s\". The text must follow the conventional commit specification. More about: https://www.conventionalcommits.org.\n" "$1"

    exit 1
fi