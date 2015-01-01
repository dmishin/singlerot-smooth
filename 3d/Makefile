all: lines.treejs.js

lines-app.js: lines-app.coffee
	coffee -c lines-app.coffee


lines.treejs.js: lines-app.js
	browserify -o lines.treejs.js lines-app.js


clean:
	rm lines.treejs.js lines-app.js


