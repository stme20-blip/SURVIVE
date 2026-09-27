// Build each release from the current working project, never an older release.
import {copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {dirname, extname, join} from 'node:path';

const project = fileURLToPath(new URL('../오염구역-테스트/', import.meta.url));
const version = process.argv[2];
if (!/^v\d+$/.test(version ?? '')) throw Error('Usage: node scripts/stage_web_release.mjs v36 [--verify]');
const stage = join(project, 'build', `web-release-${version}`);
const excluded = new Set(['.git', '.github', '.godot', '.vscode', 'build', 'builds', 'dist', 'docs', 'supabase', 'tests', 'tools']);
const resources = new Set(['.gd', '.uid', '.tscn', '.tres', '.godot', '.cfg', '.gdshader', '.gdshaderinc', '.svg', '.json', '.png', '.jpg', '.jpeg', '.webp', '.ogg', '.wav', '.mp3', '.otf', '.ttf', '.res', '.csv', '.translation']);
function files(dir = '') {
  return readdirSync(join(project, dir), {withFileTypes: true}).flatMap(entry => {
    const relative = join(dir, entry.name);
    if (entry.isDirectory()) return excluded.has(entry.name) ? [] : files(relative);
    return resources.has(extname(entry.name)) ? [relative] : [];
  });
}
function expected(file) {
  let bytes = readFileSync(join(project, file));
  if (file === 'export_presets.cfg') {
    const template = process.env.GODOT_WEB_TEMPLATE;
    if (!template || !existsSync(template)) throw Error('Set GODOT_WEB_TEMPLATE to the installed web export template');
    // Change only the Web preset; game files and desktop configuration stay exact.
    const text = bytes.toString('utf8');
    const index = text.indexOf('[preset.1.options]');
    if (index < 0 || !text.includes('platform="Web"')) throw Error('Web export preset missing');
    bytes = Buffer.from(text.slice(0, index) + text.slice(index).replace(/custom_template\/release="[^"]*"/, `custom_template/release="${template.replaceAll('\\', '/')}"`));
  }
  return bytes;
}
const sourceFiles = files();
if (!process.argv.includes('--verify')) {
  if (existsSync(stage)) throw Error('Use a fresh release directory to avoid stale files');
  for (const file of sourceFiles) {
    mkdirSync(dirname(join(stage, file)), {recursive: true});
    if (file === 'export_presets.cfg') writeFileSync(join(stage, file), expected(file));
    else copyFileSync(join(project, file), join(stage, file));
  }
}
const manifest = [];
for (const file of sourceFiles) {
  const bytes = expected(file);
  if (!existsSync(join(stage, file)) || !bytes.equals(readFileSync(join(stage, file)))) throw Error(`Release differs from current project: ${file}`);
  manifest.push({file, sha256: createHash('sha256').update(bytes).digest('hex')});
}
writeFileSync(join(project, 'build', `${version}-source-manifest.json`), JSON.stringify(manifest, null, 2));
console.log(`PASS: ${sourceFiles.length} current project files match ${version}; only the web template path is adjusted`);
