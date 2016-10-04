A2O_TARGET = debug
HTML = a2o/build/$(A2O_TARGET)/products/application/application.html

.PHONY: all xcodebuild clean run runff

all: xcodebuild

$(HTML): xcodebuild

xcodebuild:
	a2obrew xcodebuild -t ${A2O_TARGET}

clean:
	a2obrew xcodebuild -c -t ${A2O_TARGET}

run:
	emrun --browser chrome_canary $(HTML)

runff:
	emrun --kill_start --browser firefox_nightly --profile=emscripten_user $(HTML)
