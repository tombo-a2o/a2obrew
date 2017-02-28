#!/bin/sh -exu
node ../node_modules/eslint/bin/eslint.js --config=.eslintrc --fix shell_files/javascripts/shell.js
node ../node_modules/eslint/bin/eslint.js --config=.eslintrc2016 --fix shell_files/javascripts/ws.js
node ../node_modules/htmlhint/bin/htmlhint --config=.htmlhintrc shell.html
node ../node_modules/csslint/dist/cli.js --config=.csslintrc shell_files/stylesheets/shell.css
