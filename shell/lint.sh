#!/bin/sh -exu
node ../node_modules/eslint/bin/eslint.js --config=.eslintrc --fix shell_files/javascripts/shell.js
node ../node_modules/htmlhint/bin/htmlhint --config=.htmlhintrc shell.html
