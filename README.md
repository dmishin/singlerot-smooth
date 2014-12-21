singlerot-smooth
================
"Single Rotation" cellular automaton demonstration with Lanczos smoothing.

![Sample picture](./singlerot-smooth.png)

[Single Rotation](http://dmishin.blogspot.ru/2013/11/the-single-rotation-rule-remarkably.html)
is a very simple yet rich reversible cellular automaton.
Unlike the famous [Game of Life](http://en.wikipedia.org/wiki/Conway%27s_Game_of_Life), it preserves total number of alive cells.
This allows to track the trajectory of each cell as it moves through the field during its evolution.


This program demonstrates these trajectories, using HTML5 Canvas for GUI and JavaScript for computations.

Compilation
-----------

The code is written in CoffeeScript, and uses _browserify_ and _minify_ tools. To compile, type:

  $ make

Running
-------
Open the HTML file in the browser.


Browser support
---------------

Thr program uses following features:
 * Canvas
 * Typed arrays
 * Animation with requestAnimationFrame
 
All these features should be supported in the most desktop and many mobile browsers.