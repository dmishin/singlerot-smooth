all: flight.js

revca_track.js: revca_track.coffee
	coffee -c revca_track.coffee

flight-app.js: flight-app.coffee
	coffee -c flight-app.coffee

flight.js: flight-app.js revca_track.js
	browserify flight-app.js -o flight.js

flight.min.js: flight.js
	uglifyjs --screw-ie8 flight.js -o flight.min.js

clean:
	rm revca_track.js flight-app.js flight.js\
	   flight.min.js


