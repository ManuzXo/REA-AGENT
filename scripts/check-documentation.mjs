import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, extname, isAbsolute, join, relative, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const repository = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const argumentsList = process.argv.slice(2);
const failures = [];
let packagePath;
for (let index = 0; index < argumentsList.length; index += 1) {
  if (argumentsList[index] !== '--package' || !argumentsList[index + 1] || packagePath) {
    throw new Error('Uso: node scripts/check-documentation.mjs [--package PERCORSO_PACCHETTO_REA]');
  }
  packagePath = resolve(argumentsList[index + 1]);
  index += 1;
}

function markdownFiles(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) return markdownFiles(path);
    return entry.isFile() && extname(path) === '.md' ? [path] : [];
  });
}

const files = [join(repository, 'README.md'), ...markdownFiles(join(repository, 'docs'))];
for (const file of files) {
  const contents = readFileSync(file, 'utf8');
  const prose = contents.replace(/^(`{3,}|~{3,})[^\n]*\n[\s\S]*?^\1\s*$/gm, '');
  for (const match of prose.matchAll(/\]\((<[^>]+>|[^\s)]+)(?:\s+"[^"]*")?\)/g)) {
    const target = match[1].replace(/^<|>$/g, '').split('#')[0];
    if (!target || /^(?:[a-z][a-z0-9+.-]*:|\/\/)/i.test(target)) continue;
    const localPath = resolve(dirname(file), decodeURIComponent(target));
    if (!existsSync(localPath)) failures.push(`${relative(repository, file)}: link locale assente ${target}`);
  }
  if (/\brea\.bat\b/i.test(contents)) failures.push(`${relative(repository, file)}: nome rea.bat obsoleto`);
}
if (existsSync(join(repository, 'rea.bat'))) failures.push('rea.bat nella radice nasconde il comando REA di npx.');

if (packagePath) {
  const contractsPath = statSync(packagePath).isDirectory()
    ? join(packagePath, 'dist', 'contracts', 'toolContracts.js')
    : packagePath;
  if (!isAbsolute(contractsPath)) throw new Error('Il percorso del catalogo deve essere assoluto.');
  const { TOOL_CONTRACTS } = await import(pathToFileURL(contractsPath).href);
  const expected = new Set(TOOL_CONTRACTS.map(({ name }) => name));
  const document = readFileSync(join(repository, 'docs', 'rea-capabilities.md'), 'utf8');
  const heading = '## Inventario completo del pacchetto 6.5.0';
  const headingIndex = document.indexOf(heading);
  if (headingIndex < 0) failures.push('Intestazione inventario completo assente.');
  const appendix = headingIndex < 0 ? '' : document.slice(headingIndex + heading.length);
  const observedNames = [...appendix.matchAll(/`([a-z][a-z0-9_]+)`/g)].map((match) => match[1]);
  const observed = new Set(observedNames);
  for (const name of expected) if (!observed.has(name)) failures.push(`Tool assente dall'inventario: ${name}`);
  for (const name of observed) if (!expected.has(name)) failures.push(`Tool estraneo al pacchetto: ${name}`);
  for (const name of observed) {
    if (observedNames.filter((candidate) => candidate === name).length > 1) failures.push(`Tool duplicato: ${name}`);
  }
  console.log(`Inventario confrontato con ${expected.size} tool del pacchetto selezionato.`);
}

for (const failure of failures) console.error(failure);
console.log(`${files.length} documenti controllati. ${failures.length} errori.`);
if (failures.length) process.exitCode = 1;
