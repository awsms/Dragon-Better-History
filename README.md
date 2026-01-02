# Dragon-Better-History

Better history for Chromium-based browsers.

## Build

### On Linux

Install the tools globally (any Node package manager is fine). You need:
- `lessc` with `less-plugin-clean-css`
- `terser`

Example with npm:
```sh
npm i -g less less-plugin-clean-css terser
```

Then build or watch:
```sh
./run-build.sh
./run-watch.sh
```
___

### On Windows

Install the same tools globally:
```pwsh
npm i -g less less-plugin-clean-css terser
```

Build outputs:
```pwsh
# CSS
lessc .\src\css\history.less .\build\assets\application.css --clean-css="--s0 --advanced"

# JS (compile each file to src/js/compiled)
terser .\src\js\<name>.js --output .\src\js\compiled\<name>.js --comments false

# Merge in the order listed in _merge.txt
Get-Content .\src\js\_merge.txt | ForEach-Object { Get-Content .\src\js\compiled\$_ } | Set-Content .\build\assets\application.js
```
___

Note: If you add new JavaScript files, update `src/js/_merge.txt` so they are included in the bundle.

## Install

1) Open `chrome://extensions/`
2) Enable **Developer mode**
3) Click **Load unpacked**
4) Select the `build/` folder