# Math Stuff
- Compute eigenvalues and eigenvectors

# Rendering Stuff
- Camera options
    - Fixing in place
        - Object creation menu
- Render an object and its projection
- Animation

# Clean Up





- Widget UI Elements
    - Element itself
        - Callback fn on update (defined during construction for each widget)





- There are memory leaks somewhere
- Cleanup the GUI because it's sloppy, just wanted to get something down
    - Raylib draws text so that each character takes up different length of space, so there is issue calculating cursor position
- Soon need to do some code review and cleanup
- Naming conventions (why is the visualizer/simulator "Sim"? Make things more descriptive/clearer)
- Create solid documentation for math functions
- Figure out how to move tests in dedicated test files and not have to keep all in one big file
    - Will involve necessary alterations to `build.zig`
- Clean up unnecessary errors