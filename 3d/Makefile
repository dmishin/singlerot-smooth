all: singlerot3d-app.js tubing_worker_app.js ../


tubing.js: tubing.coffee
	coffee -c tubing.coffee

singlerot3d.js: singlerot3d.coffee
	coffee -c singlerot3d.coffee

tubing_worker.js: tubing_worker.coffee
	coffee -c tubing_worker.coffee

tubing_worker_app.js: tubing_worker.js tubing.js
	browserify -o tubing_worker_app.js tubing_worker.js

singlerot3d-app.js: singlerot3d.js tubing.js
	browserify -o singlerot3d-app.js singlerot3d.js

clean:
	rm tubing.js singlerot3d.js tubing_worker.js  tubing_worker_app.js singlerot3d-app.js


.PHONY: clean
