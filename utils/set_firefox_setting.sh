#!/usr/bin/env python

import glob
import subprocess
import time
import os

executable = "/Applications/FirefoxNightly.app/Contents/MacOS/firefox"
user_name = "emscripten_user"

prefs_pattern = os.path.expanduser("~/Library/Application Support/Firefox/Profiles/*.%s/prefs.js" % user_name)
prefs = glob.glob(prefs_pattern)

# create profile
if len(prefs) == 0:
  p = subprocess.Popen([executable, "-CreateProfile", user_name])
  p.wait()
  prefs = glob.glob(prefs_pattern)

prefs = prefs[0]

# generate prefs.js
if os.path.getsize(prefs) == 0:
  p = subprocess.Popen([executable, "-P", user_name])
  time.sleep(3)
  p.kill()

props = {
  "browser.popups.showPopupBlocker": "false", 
  "browser.shell.checkDefaultBrowser": "false", 
  "browser.sessionstore.resume_from_crash": "false", 
  "services.sync.prefs.sync.browser.sessionstore.restore_on_demand": "false", 
  "browser.sessionstore.restore_on_demand": "false", 
  "browser.sessionstore.max_resumed_crashes": -1, 
  "toolkit.startup.max_resumed_crashes": -1,
  "dom.max_script_run_time": 0, 
  "dom.max_chrome_script_run_time": 0, 
  "app.update.download.backgroundInterval": 1, 
  "browser.privatebrowsing.autostart": "true", 
  "startup.homepage_override_url": '"about:blank"', 
  "startup.homepage_welcome_url": '"about:blank"', 
  "dom.workers.maxPerDomain": 100,
}

with open(prefs, "r") as f:
  lines = f.readlines()

with open(prefs, "w") as f:
  for line in lines:
    for prop in props:
      if prop in line:
        break
    else: 
      f.write(line)
  for prop in props:
    f.write('user_pref("%s", %s);\n' % (prop, props[prop]))
