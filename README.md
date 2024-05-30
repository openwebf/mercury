# mercury

QuickJS bindings and web-compliant polyfills wrapped up in flutter library with [legacy](https://github.com/openkraken/kraken) behind it. Aims to be an efficient & fully-featured library to run JavaScript in a flutter app, from simple eval to acting as the app's logic/backend core.

Eventually, this library will be used by https://github.com/openwebf/webf as a superset to provide DOM interactions and rendering. This should also encourage better maintenance, as WebF contributors iterating on the JS core of the framework will contribute here. See https://github.com/openwebf/mercury/issues/16

## Installation

It's best if you have [pnmp](https://pnpm.io/) installed, in which case run:
```bash
pnpm install
```
If you only have `npm` installed, disregard the various warnings

Once installed, you can build all operating systems like this:
```bash
npm run build:bridge:all
```
or any particular one by replacing `all` above with any of: `macos`, `linux`, `android`, `windows` or `ios`, and any of these can be suffixed with `:release` to build production-ready versions of the bridge

## Example

We provide an example you can run like this:
```bash
cd mercury/example
flutter run
```
and if you want to play with the Javascript, edit the `assets/bundle.js` file

### Prior Art
- https://github.com/abner/flutter_js

### Dependant Projects
- https://github.com/RefractureMedia/refracture-music
