import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(scriptDir, '..');
const repoRoot = path.resolve(appRoot, '..', '..');
const dataFile = path.join(appRoot, 'src', 'data', 'labData.ts');

const source = fs.readFileSync(dataFile, 'utf8');
const failures = [];

const requiredExports = [
  'labSummary',
  'metrics',
  'phases',
  'scripts',
  'validationChecks',
  'securityControls',
  'runbooks',
  'quickActions',
  'safetyRules',
];

const requiredIds = [
  'phase-0',
  'phase-1',
  'phase-2',
  'phase-3',
  'phase-4',
  'phase-5',
  'phase-6',
  'teardown',
  'provision',
  'attach-iso',
  'setup-dc',
  'join-domain',
  'configure-gpos',
  'create-users',
  'validate',
  'harden',
  'monitoring',
  'backup',
  'restore',
  'advanced-gpos',
  'rbac',
  'domain-controller',
  'ou-structure',
  'clients-joined',
  'password-policy',
  'usb-restriction',
  'user-volume',
  'wef-subscription',
  'backup-artifacts',
  'ntlmv2',
  'smb-signing',
  'defender-asr',
  'script-block-logging',
  'wef',
  'rbac',
  'rb-001',
  'rb-002',
  'rb-003',
  'rb-004',
  'rb-005',
  'rb-006',
  'syntax',
  'pester',
  'validate-lab',
  'backup-lab',
];

for (const exportName of requiredExports) {
  if (!source.includes(`export const ${exportName}`)) {
    failures.push(`Missing export: ${exportName}`);
  }
}

const ids = [...source.matchAll(/id: '([^']+)'/g)].map((match) => match[1]);
const idCounts = new Map();

for (const id of ids) {
  idCounts.set(id, (idCounts.get(id) ?? 0) + 1);
}

for (const id of requiredIds) {
  if (!idCounts.has(id)) {
    failures.push(`Missing data id: ${id}`);
  }
}

for (const [id, count] of idCounts) {
  if (count > 1 && id !== 'rbac') {
    failures.push(`Duplicate data id: ${id}`);
  }
}

const referencedPaths = [...source.matchAll(/path: '([^']+)'/g)].map((match) => match[1]);

for (const relativePath of referencedPaths) {
  const absolutePath = path.join(repoRoot, relativePath);
  if (!fs.existsSync(absolutePath)) {
    failures.push(`Referenced path does not exist: ${relativePath}`);
  }
}

const forbiddenPatterns = [
  /LabAdm1n/i,
  /password\s*=\s*['"][^'"]+['"]/i,
  /Invoke-Expression/i,
];

for (const pattern of forbiddenPatterns) {
  if (pattern.test(source)) {
    failures.push(`Forbidden dashboard data pattern found: ${pattern}`);
  }
}

if (failures.length > 0) {
  console.error('Dashboard data validation failed:');
  for (const failure of failures) {
    console.error(`- ${failure}`);
  }
  process.exit(1);
}

console.log(`Dashboard data validation passed: ${ids.length} ids and ${referencedPaths.length} repo paths checked.`);
