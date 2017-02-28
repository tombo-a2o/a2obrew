'use strict';

var Module;
var A2OShell;

(function () {
  var messages = {
    downloadSize: {
      en: 'Download size is approx. ',
      ja: 'ダウンロードサイズ: 約'
    },
    warningOnMobile: {
      en: 'This app may not work correctly on mobile devices due to insufficient memory or CPU power.\nWould you like to launch the app?',
      ja: 'モバイル端末で実行する場合\u3001メモリやCPUパワーの不足で正常に実行されない恐れがあります\u3002\n実行してもよろしいですか\uFF1F'
    },
    warningNonSupportedBrowsers: {
      en: 'This app may not work correctly on your browser.\nWould you like to launch the app?',
      ja: 'お使いのブラウザでは正常に実行されない恐れがあります\u3002\n実行してもよろしいですか\uFF1F'
    },
    exception: {
      en: 'Oops! Looks like something went wrong. Please try reloading the page.',
      ja: '問題が発生しました。申し訳ございませんが、ページをリロードしてください。'
    },
    detailsTitle: {
      en: 'Under the Hood:',
      ja: 'どうやって動いているの？'
    },
    detailsText: {
      en: '<p>This app was auto-converted from iOS to Web using the <a target="_blank" href="http://tombo.io/a2o/">"A2O" converter</a> by <a target="_blank" href="http://tombo.io/">Tombo, Inc.</a>. If you\'re interested in converting your apps to the Web using A2O, <a target="_blank" href="http://tombo.io/contact_form/">we\'d love to talk to you</a>.<p>Details about the technology can be found in <a target="_blank" href="https://blog.tombo.io/">our blog</a>. <a target="_blank" href="http://tombo.io/contact_form/">Feedback welcome!</a>',
      ja: '<p>このアプリは<a target="_blank" href="http://tombo.io/">Tombo Inc.</a>で開発した<a target="_blank" href="http://tombo.io/a2o/">A2Oコンバーター</a>によってiOSアプリから自動変換されています。もし、アプリを変換することに興味がある場合、ぜひ<a target="_blank" href="http://tombo.io/contact_form/">ご連絡</a>ください。<p>技術的な詳細については私たちの<a target="_blank" href="https://blog.tombo.io/">ブログ（ただし英語）</a>をご覧ください。<a target="_blank" href="http://tombo.io/contact_form/">フィードバック</a>大歓迎です！'
    },
    warningBeforeUnload: {
      en: 'Application will be terminated.',
      ja: 'アプリが中断されます。'
    },
    appStoreBadgePath: {
      en: './shell_files/images/app_store_badge.en.svg',
      ja: './shell_files/images/app_store_badge.ja.svg'
    },
    googlePlayBadgePath: {
      en: './shell_files/images/google_play_badge.en.svg',
      ja: './shell_files/images/google_play_badge.ja.svg'
    },
  };

  // Getting runtime_paramters.json
  var loadRuntimeParameters = function (callback) {
    var xhr = new XMLHttpRequest();
    xhr.onload = function () {
      var rp = JSON.parse(this.responseText);
      Module = rp.Module;
      A2OShell = rp.A2OShell;

      /* setup Module */
      Module.preRun = [];
      Module.postRun = [];
      Module.print = function (text) {
        if (arguments.length > 1) text = Array.prototype.slice.call(arguments).join(' ');
        console.log(text);
      };
      Module.printErr = function (text) {
        if (arguments.length > 1) text = Array.prototype.slice.call(arguments).join(' ');
        console.error(text);
      };
      Module.canvas = (function () {
        var canvas = document.getElementById('app-canvas');

        // As a default initial behavior, pop up an alert when webgl context is lost. To make your
        // application robust, you may want to override this behavior before shipping!
        // See http://www.khronos.org/registry/webgl/specs/latest/1.0/#5.15.2
        canvas.addEventListener('webglcontextlost', function (e) {
          alert('Please reload the page');
          e.preventDefault();
        }, false);

        return canvas;
      })();
      Module.setStatus = function (text) {
        if (!Module.setStatus.last) Module.setStatus.last = { time: Date.now(), text: '' };
        if (text === Module.setStatus.text) return;
        var statusElement = document.getElementById('status');
        statusElement.style.display = (text === '' ? 'none' : 'table');
        var m = text.match(/([^(]+)\((\d+(\.\d+)?)\/(\d+)\)/);
        var now = Date.now();
        if (m && now - Module.setStatus.last.time < 30) return; // if this is a progress update, skip it if too soon
        if (m) {
          text = m[1] + ': ' + (parseInt(m[2]) / parseInt(m[4]) * 100).toFixed(2) + '%';
        }
        var statusMessageElement = document.getElementById('status-message');
        statusMessageElement.textContent = text;
      };
      Module.totalDependencies = 0;
      Module.monitorRunDependencies = function (left) {
        this.totalDependencies = Math.max(this.totalDependencies, left);
        Module.setStatus(left ? 'Preparing... (' + (this.totalDependencies - left) + '/' + this.totalDependencies + ')' : 'All downloads complete.');
      };
      callback();
    };
    xhr.open('GET', 'runtime_parameters.json', true);
    xhr.send(null);
  };

  var current_url = (function () {
    var metas = document.getElementsByTagName('meta');
    for (var i = 0; i < metas.length; i++) {
      if (metas[i].getAttribute('property') == 'og:url') {
        return metas[i].getAttribute('content')
      }
    }
  })() || window.location;

  var script = document.createElement('script');
  script.src = 'application.asm.js';
  script.onload = function () {
    setTimeout(function () {
      (function () {
        var memoryInitializer = 'application.js.mem';
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

  var isSupportedBrowser = function () {
    var canvas = document.createElement('canvas');
    var gl = canvas.getContext('webgl');
    if (!gl || !gl.getExtension('OES_vertex_array_object')) {
      return false;
    }
    try {
      new AudioContext();
    } catch (_e) {
      return false;
    }
    return true;
  }

  var loadWasm = function () {
    var xhr = new XMLHttpRequest();
    xhr.open('GET', 'application.wasm', true);
    xhr.responseType = 'arraybuffer';
    xhr.onload = function () {
      Module.wasmBinary = xhr.response;

      var script = document.createElement('script');
      script.src = 'application.js';
      document.body.appendChild(script);

    };
    xhr.send(null);
  }

  var locale = 'en';
  var launch = function () {
    // show warning if this is mobile
    var ua = navigator.userAgent || navigator.vendor || window.opera;
    if (ua.match(/iPad|iPhone|iPod|Android|(IE| )Mobile[;\/ ]| Tablet;/i)) {
      if (!confirm(messages.warningOnMobile[locale])) {
        return;
      }
    }

    var canvas = document.getElementById('app-canvas');

    if (!isSupportedBrowser()) {
      if (!confirm(messages.warningNonSupportedBrowsers[locale])) {
        return;
      }
    }

    canvas.addEventListener('wheel', function (e) {
      e.preventDefault();
    });
    var fireSwipe = function (dx, dy) {
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
      var raf = function () {
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
        button.addEventListener('mousedown', function (_e) {
          fireSwipe(0, 0);
          return false;
        });
        break;
      case '3way-down':
        document.getElementById('button-swipe-left').addEventListener('mousedown', function (_e) {
          fireSwipe(-1, 0);
          return false;
        });
        document.getElementById('button-swipe-down').addEventListener('mousedown', function (_e) {
          fireSwipe(0, 1);
          return false;
        });
        document.getElementById('button-swipe-right').addEventListener('mousedown', function (_e) {
          fireSwipe(1, 0);
          return false;
        });
        // add key listener
        document.addEventListener('keydown', function (e) {
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

    if (A2OShell.wasm) {
      loadWasm();
    } else {
      document.body.appendChild(script);
    }
  };

  var launchWithServiceWorker = function () {
    registerServiceWorker(function () {
      launch();
    });
  };

  var getCookieAsObject = function () {
    return document.cookie.split('; ').reduce(function (prev, current, _index, _array) {
      var keyvalue = current.split('=');
      prev[keyvalue[0]] = keyvalue[1];
      return prev;
    }, {});
  };

  var getLocalizeLanguages = function () {
    // Browser languages
    var languages = window.navigator.languages ? window.navigator.languages : [window.navigator.language];

    // Use platform language settings if exist
    var cookie = getCookieAsObject();
    if (cookie.locale) {
      languages = languages.filter(function (element, _index, _array) {
        return element != cookie.locale;
      });
      languages.unshift(cookie.locale);
    }
    return languages;
  };

  var setLanguageEnv = function (languages) {
    if (!Module.preRun) {
      Module.preRun = [];
    }
    Module.preRun.push(function () {
      ENV.LANGUAGES = '(' + languages.join(',') + ')';
    });
  };

  var localizeShell = function () {
    // set download text
    var downloadSizeElement = document.getElementsByClassName('playground-download-size')[0];
    if (downloadSizeElement && A2OShell.totalFileSize) {
      downloadSizeElement.textContent = messages.downloadSize[locale] + A2OShell.totalFileSize;
    }
    var detailsTitle = document.getElementById('details-title');
    if (detailsTitle) {
      detailsTitle.innerHTML = messages.detailsTitle[locale];
    }
    var detailsText = document.getElementById('details-text');
    if (detailsText) {
      detailsText.innerHTML = messages.detailsText[locale];
    }
    var appStoreLinkImage = document.getElementById('app-store-link-image');
    var googlePlayLinkImage = document.getElementById('google-play-link-image');
    if (appStoreLinkImage && googlePlayLinkImage) {
      appStoreLinkImage.src = messages.appStoreBadgePath[locale];
      googlePlayLinkImage.src = messages.googlePlayBadgePath[locale];
    }
  };

  var prepareLocalization = function () {
    var languages = getLocalizeLanguages();

    setLanguageEnv(languages);

    // set locale
    for (var i = 0; i < languages.length; i++) {
      var lang = languages[i].substring(0, 2);
      if (lang === 'ja' || lang === 'en') {
        locale = lang;
        break;
      }
    }

    localizeShell();
  };

  var prepareErrorHandler = function () {
    var environment = window.location.hostname == 'app.tombo.io' ? 'production' : 'development';
    if (environment == 'production') {
      var airbrake = new airbrakeJs.Client({
        projectId: 137659,
        projectKey: '9616430610ed0f212cf574caf6de20dd',
        onerror: false
      });

      window.addEventListener('error', function (event) {
        var error = event.error;
        if (typeof error === 'object' && !(error instanceof Error)) error = JSON.stringify(error);
        airbrake.notify({
          error: error,
          context: { environment: environment }
        });
      });
    }
  };

  var registerServiceWorker = function (callback) {
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('../../sw.js').then(function (registration) {
        console.log('ServiceWorker registration successful with scope: ', registration.scope)
        callback();
      }).catch(function (err) {
        console.log('ServiceWorker registration failed: ', err);
        callback();
      });
    } else {
      console.log('No ServiceWorker');
      callback();
    }
  };

  var main = function () {
    prepareLocalization();

    prepareErrorHandler();

    // initializing screen size
    var isLandscape = Module.initialDeviceOrientation == 3;
    var width;
    var height;
    var scale = Module.screenModes[0].scale;
    var launchImage = document.getElementById('launch-image');
    if (isLandscape) {
      width = Module.screenModes[0].height / scale;
      height = Module.screenModes[0].width / scale;
      launchImage.style.transform = 'rotate(-90deg)';
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
    var keypadElement = document.getElementById('keypad-' + A2OShell.keypad);
    keypadElement && (keypadElement.style.display = 'block');

    // adding events on buttons
    document.getElementById('button-launch').addEventListener('click', function (_e) {
      launchWithServiceWorker();
      return false;
    });
    document.getElementById('button-tweet').addEventListener('click', function (_e) {
      window.open('https://twitter.com/intent/tweet?url=' + encodeURIComponent(current_url) + '&hashtags=' + encodeURIComponent('tomboapp') + '&via=tomboinc');
      return false;
    });
    document.getElementById('button-share-on-facebook').addEventListener('click', function (_e) {
      window.open('https://www.facebook.com/sharer/sharer.php?u=' + encodeURIComponent(current_url));
      return false;
    });

    document.getElementById('app-store-link').href = A2OShell.appStoreURL || '#';
    document.getElementById('google-play-link').href = A2OShell.googlePlayURL || '#';

    window.addEventListener('beforeunload', function (e) {
      var message = messages.warningBeforeUnload[locale];
      e.returnValue = message;
      return message;
    });

    window.addEventListener('error', function (_event) {
      // TODO: do not warn on ok events like simulating an infinite loop or exitStatus
      Module.setStatus(messages.exception[locale]);
      Module.setStatus = function (text) {
        if (text) Module.printErr('[post-exception status] ' + text);
      };
    });

    // auto launch
    if (A2OShell.autoLaunch) {
      launchWithServiceWorker();
    }
  };

  document.addEventListener('DOMContentLoaded', function () {
    loadRuntimeParameters(function () {
      main();
    });
  });
}());
