(function() {
  var messages = {
    warningOnMobile: {
      en: 'It might not work correctly on mobile devices due to the short of memory or CPU power.\nAre you sure to start this app?',
      ja: 'モバイル端末で実行する場合\u3001メモリやCPUパワーの不足で正常に実行されない恐れがあります\u3002\n実行してもよろしいですか\uFF1F'
    }
  };

  var script = document.createElement('script');
  script.src = 'application.asm.js';
  script.onload = function() {
    setTimeout(function() {
      (function() {
        var memoryInitializer = 'application.html.mem';
        if (typeof Module.locateFile === 'function') {
          memoryInitializer = Module.locateFile(memoryInitializer);
        } else if (Module.memoryInitializerPrefixURL) {
          memoryInitializer = Module.memoryInitializerPrefixURL + memoryInitializer;
        }
        var xhr = Module.memoryInitializerRequest = new XMLHttpRequest();
        xhr.open('GET', memoryInitializer, true);
        xhr.responseType = 'arraybuffer';
        xhr.send(null);
      }());
      var script = document.createElement('script');
      script.src = 'application.js';
      document.body.appendChild(script);
    }, 1); // delaying even 1ms is enough to allow compilation memory to be reclaimed
  };
  var locale = 'en';
  window.start = function() {
    // show warning if this is mobile
    var ua = navigator.userAgent || navigator.vendor || window.opera;
    if (ua.match(/iPad|iPhone|iPod|Android|(IE| )Mobile[;\/ ]| Tablet;/i)) {
      if (!confirm(messages.warningOnMobile[locale])) {
        return;
      }
    }
    var canvas = document.getElementById('app-canvas');
    canvas.addEventListener('wheel', function(e) {
      e.preventDefault();
    });
    var fireSwipe = function(dx, dy) {
      if (fireSwipe.working) {
        return;
      }
      fireSwipe.working = true;
      var canvas = document.getElementById('app-canvas');
      var element = canvas;
      var left = 0;
      var top = 0;
      while (element) {
        left += element.offsetLeft - element.scrollLeft;
        top += element.offsetTop - element.scrollTop;
        element = element.parentElement;
      }
      // touch starts from center
      var x = canvas.width / 2;
      var y = canvas.height / 2;
      // 4 frames
      var n = 4;
      if (dx == dy) {
        // not swipe, just tap
        n = 1;
      }
      // moves 15 pixels per frame
      dx *= 15;
      dy *= 15;
      if (typeof Event === 'undefined') {
        console.log('Oops! Your browser does not support Event object');
        return;
      }
      var frame = 0;
      var raf = function() {
        var event;
        var end = false;
        if (frame == 0) {
          event = new Event('touchstart');
        } else if (frame >= n) {
          event = new Event('touchend');
          end = true;
        } else {
          x += dx;
          y += dy;
          event = new Event('touchmove');
        }
        frame++;
        event.changedTouches = [{
          identifier: 1,
          clientX: x + left,
          clientY: y + top,
          screenX: x + left,
          screenY: y + top,
          pageX: x + left,
          pageY: y + top,
          force: 0,
          target: canvas
        }];
        if (!end) {
          event.touches = event.targetTouches = event.changedTouches;
        } else {
          event.touches = event.targetTouches = [];
        }
        canvas.dispatchEvent(event);
        if (!end) {
          window.requestAnimationFrame(raf);
        } else {
          fireSwipe.working = false;
        }
      };
      // invoke touch events
      window.requestAnimationFrame(raf);
    };

    switch (A2OShell.keypad) {
      case 'tap':
        var button = document.getElementById('button-tap');
        button.addEventListener('mousedown', function (e) {
          fireSwipe(0, 0);
          return false;
        });
        break;
      case '3way-down':
        document.getElementById('button-swipe-left').addEventListener('mousedown', function (e) {
          fireSwipe(-1, 0);
          return false;
        });
        document.getElementById('button-swipe-down').addEventListener('mousedown', function (e) {
          fireSwipe(0, 1);
          return false;
        });
        document.getElementById('button-swipe-right').addEventListener('mousedown', function (e) {
          fireSwipe(1, 0);
          return false;
        });
        // add key listener
        document.addEventListener('keydown', function(e) {
          switch (e.which) {
            case 37:
              // ←
              fireSwipe(-1, 0);
              e.preventDefault();
              break;
            case 39:
              // →
              fireSwipe(1, 0);
              e.preventDefault();
              break;
            case 40:
              // ↓
              fireSwipe(0, 1);
              e.preventDefault();
              break;
          }
        });
        break;
    }
    document.getElementById('app-canvas').style.display = 'block';
    document.getElementById('preview-image').style.display = 'none';
    Module.setStatus('Downloading...');
    document.body.appendChild(script);
  };
  document.addEventListener('DOMContentLoaded', function() {
    // get locale
    var languages = window.navigator.languages ? window.navigator.languages : [window.navigator.language];
    var cookie = document.cookie.split('; ').reduce(function(p, c, i, a) {
      var kv = c.split('=');
      p[kv[0]] = kv[1];
      return p;
    }, {});
    if (cookie.locale) {
      languages = languages.filter(function(e, i, a) {
        return e != cookie.locale;
      });
      languages.unshift(cookie.locale);
    }
    if (!Module.preRun)
      Module.preRun = [];
    Module.preRun.push(function() {
      ENV.LANGUAGES = '(' + languages.join(',') + ')';
    });
    // get locale
    for (var i = 0; i < languages.length; i++) {
      var lang = languages[i].substring(0, 2);
      if (lang === 'ja' || lang === 'en') {
        locale = lang;
        break;
      }
    }
    // initializing screen size
    var isLandscape = Module.initialDeviceOrientation == 3;
    var width;
    var height;
    var scale = Module.screenModes[0].scale;
    if (isLandscape) {
      width = Module.screenModes[0].height / scale;
      height = Module.screenModes[0].width / scale;
    } else {
      width = Module.screenModes[0].width / scale;
      height = Module.screenModes[0].height / scale;
    }
    // canvas
    var canvas = document.getElementById('app-canvas');
    canvas.width = width;
    canvas.height = height;
    // playground
    var playgroundElement = document.getElementsByClassName('playground-main')[0];
    playgroundElement.style.width = width + 'px';
    playgroundElement.style.height = height + 'px';
    // background image
    var backgroundImageElement = playgroundElement.getElementsByTagName('img')[0];
    backgroundImageElement.width = width;
    backgroundImageElement.height = height;
    // initializing keypad
    var keypadElement = document.getElementsByClassName('playground-keypad-' + A2OShell.keypad)[0];
    keypadElement && (keypadElement.style.display = 'block');
    if (Module.autoStart) {
      start();
    }
  });
}());
