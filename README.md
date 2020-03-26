# Blog
Projectwork for 'DynamicWebApp 2020' -course.

## Project submodules
 - ### [Backend repository](https://github.com/HeikkiKangas/Blog-Backend/tree/dev)
 - ### [Frontend repository](https://github.com/HeikkiKangas/Blog-Frontend/tree/dev)
   This repository is for automating the building of production-ready single-jar releases.
   If you are interested in seeing the sources of front- or backend, please check the links above.
   
## How to build
 - ### Linux and macOS
   Run following command in project root directory.
   ```sh
   $ cd < Repository path >
   $ ./package.sh
   ```
   
   If you want to create a new release to GitHub, you can use following parameters:
   ```
   '-r' to create release.
   OR
   '-pre' to create pre-release.
   AND
    '-v=< version >'
    AND
    '-m="<release message>"'
    
   e.g.
    ./package.sh -pre -v=0.1 -m="First pre-release."
    OR
    ./package.sh -r -v=1.0 -m="First release."
   ```

 - ### Windows
   Batch translation of package.sh is under consideration, not a priority.

## How to run
 - Launch `blog-release.jar` by double-clicking the file or running the following command in the same directory with the file.
   ```java
   java -jar blog-release.jar
   ```
