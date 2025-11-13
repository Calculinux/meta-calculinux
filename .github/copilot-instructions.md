# Copilot Instructions

## Instructions for Builds
- **CRITICAL**: NEVER run build commands from within the `meta-calculinux` directory itself. This creates unwanted build artifacts that must be cleaned up.
- **ALWAYS** run build commands from the `calculinux-build` directory (parent of `meta-calculinux`).
- The canonical build location is: `/home/<username>/repos/calculinux/calculinux-build/`. Note this is user specific however and may be different for different users.
- From the `calculinux-build` directory, call the kas-container helper script: `./meta-calculinux/kas-container ...`
- The `meta-calculinux` repository contains a convenience symlink `./build` that points to `../` (the calculinux-build directory), but you should use the full path instead.
- When in doubt, mirror one of these canonical invocations from `/home/<username>/repos/calculinux/calculinux-build/`:
  - `./meta-calculinux/kas-container shell ./meta-calculinux/kas-luckfox-lyra-bundle.yaml -c "bitbake aic8800"`
  - `./meta-calculinux/kas-container build ./meta-calculinux/kas-luckfox-lyra-bundle.yaml`
- Prefer these patterns for all future build steps unless explicitly instructed otherwise.
- Always wait for a build to finish before declaring it a success or failure.

## VERY IMPORTANT GUIDELINES
* DO NOT attempt to create patches without using a diff tool against actual modified source code.*
You are not able to reliably detect spacing and formatting differences that cause patches to be invalid.

* ALWAYS generate patches by modifying actual source code and using diff tools to create the patch files.*

Do not **ever** edit a patch file directly. You must correct the source file to get correct patch content. you may change the file names and paths to be patched, you may add commentary above the patch, and you may remove hunks from additional files if necessary, but you must not attempt to 'fix' patches.

If you need to modify a patch, follow the same process: modify the source code, then regenerate the patch using diff tools.

You may add comments to the patch file for clarity above the patch content, but do not alter the actual patch content. Use the editor tool only to add comments.

## Instructions for Creating Patches and Recipes
- When creating patches, follow this process:
  - Retrieve the sources to be patched
  - Make a working copy
  - Apply updates to that copy
  - Use tools like `diff` or `git` to generate the patch—never fabricate patches synthetically.
- When asked to create a recipe, always check https://layers.openembedded.org/layerindex/branch/master/recipes/?q=<query> (replacing <query> with the actual search term) to see if a suitable recipe already exists. If it does, use that as a base for your new recipe. If not, create a new recipe from scratch.
- Also check for dependencies in the same way.
- Always create temporary files in the /tmp directory or ./tmp in the repository.
