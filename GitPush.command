#!/bin/bash

cd $(dirname "$BASH_SOURCE")
git add .
git status
git commit -m 'Crash when opening up browser then story #22 -> This is fixed.'
git push whollysoftware
