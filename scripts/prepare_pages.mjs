// Make historical game URLs follow the current release before Pages upload.
import {readFileSync, writeFileSync, readdirSync, existsSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {join} from 'node:path';

const docs = fileURLToPath(new URL('../오염구역-테스트/docs/', import.meta.url));
const entry = readFileSync(join(docs, 'index.html'), 'utf8');
const current = entry.match(/url=\.\/(release-v\d+)\//)?.[1];
if (!current || !existsSync(join(docs, current, 'index.pck'))) {
  throw new Error('Current release and pack must exist before preparing Pages');
}
const redirect = `<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="refresh" content="0; url=../">
  <title>게임으로 이동</title>
  <script>location.replace('../' + location.search + location.hash);</script>
</head>
<body><a href="../">최신 게임으로 이동</a></body>
</html>
`;
let count = 0;
for (const release of readdirSync(docs, {withFileTypes: true})) {
  if (release.isDirectory() && /^release-v\d+$/.test(release.name) && release.name !== current) {
    writeFileSync(join(docs, release.name, 'index.html'), redirect);
    count++;
  }
}
console.log(`Prepared ${count} historical release redirects`);
