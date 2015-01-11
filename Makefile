all: flight.js default_library.js


rle.js: rle.coffee
	coffee -c rle.coffee

revca_track.js: revca_track.coffee
	coffee -c revca_track.coffee

flight-app.js: flight-app.coffee
	coffee -c flight-app.coffee

default_library.js: default_library.coffee
	coffee -c default_library.coffee

flight.js: flight-app.js revca_track.js rle.js fdl_parser.js
	browserify flight-app.js -o flight.js

flight.min.js: flight.js
	uglifyjs --screw-ie8 flight.js -o flight.min.js

clean:
	rm revca_track.js flight-app.js flight.js\
	   flight.min.js default_library.js parseuri.js

fdl_parser.js: fdl_parser.coffee
	coffee -c fdl_parser.coffee

pre-publish: flight.js
	cp -r flight.js default_library.js singlerot-smooth.html help.html help.css styles.css images ../dmishin.github.io/singlerot-smooth
publish: pre-publish
	cd ../dmishin.github.io/singlerot-smooth && \
	git add -A && \
	git commit -m "Publish automatically" && \
	git push 
parseuri.js: parseuri.coffee
	coffee -c parseuri.coffee
.PHONY: publish pre-publish clean
