all: singlerot3d-app.js tubing_worker_app.js 


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


pre-publish: singlerot3d-app.js tubing_worker_app.js
	mkdir -p ../../dmishin.github.io/singlerot-smooth/3d && \
	cp -r singlerot-3d.html singlerot3d-app.js tubing_worker_app.js styles.css threejs ../../dmishin.github.io/singlerot-smooth/3d/

publish: pre-publish
	cd ../../dmishin.github.io/singlerot-smooth && \
	git add -A && \
	git commit -m "Publish automatically" && \
	git push 


.PHONY: clean publish
