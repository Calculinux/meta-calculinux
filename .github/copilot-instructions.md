# Copilot Instructions

## Instructions for Builds
- When launching build commands, ensure the repository's ./build is a symlink to '../'
- Always launch build commands from the repository's `./build` directory.
- From within `./build`, call the helper from the meta-calculinux directory: `./meta-calculinux/kas-container ...`.
- When in doubt, mirror one of these canonical invocations:
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
