all: flight.js default_library.js

revca_track.js: revca_track.coffee
	coffee -c revca_track.coffee

flight-app.js: flight-app.coffee
	coffee -c flight-app.coffee

default_library.js: default_library.coffee
	coffee -c default_library.coffee

flight.js: flight-app.js revca_track.js
	browserify flight-app.js -o flight.js

flight.min.js: flight.js
	uglifyjs --screw-ie8 flight.js -o flight.min.js

clean:
	rm revca_track.js flight-app.js flight.js\
	   flight.min.js default_library.js


publish: flight.js
	cp -r flight.js default_library.js singlerot-smooth.html help.html styles.css images ../dmishin.github.io/singlerot-smooth
	cd ../dmishin.github.io/singlerot-smooth && \
	git add -A && \
	git commit -m "Publish automatically" && \
	git push 
