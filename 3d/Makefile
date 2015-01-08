all: lines.treejs.js

tubing.js: tubing.coffee
	coffee -c tubing.coffee

lines-app.js: lines-app.coffee
	coffee -c lines-app.coffee

tubing_worker.js: tubing_worker.coffee
	coffee -c tubing_worker.coffee

tubing_worker_browser.js: tubing_worker.js
	browserify -o tubing_worker_browser.js tubing_worker.js

lines.treejs.js: lines-app.js tubing.js tubing_worker_browser.js
	browserify -o lines.treejs.js lines-app.js


clean:
	rm lines.treejs.js lines-app.js


