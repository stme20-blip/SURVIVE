import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source = fs.readFileSync(new URL('../ScreenLayout.gd', import.meta.url), 'utf8');
const js = source.split('JavaScriptBridge.eval("""')[1].split('""", true)')[0];
const context = {
  window: {innerWidth: 1200, innerHeight: 700, screen: {orientation: {angle: 0}}},
  navigator: {maxTouchPoints: 0}, document: {activeElement: null}
};
vm.createContext(context);
vm.runInContext(js, context);
const size = () => JSON.parse(context.window.surviveLayoutSize());
assert.deepEqual(size(), [1200, 700]);
context.window.innerWidth = 400;
assert.deepEqual(size(), [400, 700]);
context.window.innerWidth = 1200;
assert.deepEqual(size(), [1200, 700]);
context.navigator.maxTouchPoints = 5;
context.window.innerWidth = 400;
context.window.innerHeight = 800;
assert.deepEqual(size(), [400, 800]);
context.document.activeElement = {tagName: 'TEXTAREA'};
context.window.innerHeight = 300;
assert.deepEqual(size(), [400, 800]);
context.window.screen.orientation.angle = 90;
context.window.innerWidth = 800;
context.window.innerHeight = 400;
assert.deepEqual(size(), [800, 400]);
context.document.activeElement = null;
context.window.screen.orientation.angle = 0;
context.window.innerWidth = 400;
context.window.innerHeight = 800;
assert.deepEqual(size(), [400, 800]);
console.log('PASS: desktop resize both ways, keyboard protection, mobile rotation both ways');
