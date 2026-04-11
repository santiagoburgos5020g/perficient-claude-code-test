import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

// Pre-push TDD enforcement.
// Scans ALL .tsx files in the project and blocks the push
// if any .tsx file is missing a co-located test file,
// has failing tests, or has less than 100% coverage.

interface Violation {
  type: 'missing' | 'coverage' | 'failing';
  componentPath: string;
  expectedTestPath?: string;
  coverage?: {
    lines: number;
    branches: number;
    functions: number;
    statements: number;
  };
}

const IGNORED_DIRS = ['node_modules', '.next', 'coverage', '.git', '.playwright-mcp'];

function findTsxFiles(dir: string): string[] {
  const results: string[] = [];
  if (!fs.existsSync(dir)) return results;

  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    if (IGNORED_DIRS.includes(entry.name)) continue;
    const fullPath = path.join(dir, entry.name).replace(/\\/g, '/');
    if (entry.isDirectory()) {
      results.push(...findTsxFiles(fullPath));
    } else if (
      entry.name.endsWith('.tsx') &&
      !entry.name.match(/\.(test|spec)\.tsx$/)
    ) {
      results.push(fullPath);
    }
  }
  return results;
}

function parseCoverage(
  normalizedComponent: string
): { lines: number; branches: number; functions: number; statements: number } | null {
  const coverageSummaryPath = path.join('coverage', 'coverage-summary.json');
  if (!fs.existsSync(coverageSummaryPath)) return null;

  try {
    const summary = JSON.parse(fs.readFileSync(coverageSummaryPath, 'utf-8'));
    const resolvedPath = path.resolve(normalizedComponent);
    const fileKey =
      summary[resolvedPath] !== undefined
        ? resolvedPath
        : Object.keys(summary).find(
            (k) => k !== 'total' && path.resolve(k) === resolvedPath
          );

    if (fileKey && summary[fileKey]) {
      return {
        lines: summary[fileKey].lines.pct,
        branches: summary[fileKey].branches.pct,
        functions: summary[fileKey].functions.pct,
        statements: summary[fileKey].statements.pct,
      };
    }
  } catch {
    // Could not parse coverage file
  }
  return null;
}

function main(): void {
  console.log('Pre-push TDD Enforcement: Scanning all .tsx files...');
  console.log('');

  // 1. Find ALL .tsx files in the project
  const tsxFiles = findTsxFiles('.');

  if (tsxFiles.length === 0) {
    console.log('No .tsx files found. Skipping checks.');
    process.exit(0);
  }

  console.log(`Found ${tsxFiles.length} .tsx file(s) to verify.`);
  console.log('');

  // 2. Check each component
  const violations: Violation[] = [];

  for (const component of tsxFiles) {
    const normalizedComponent = component.replace(/\\/g, '/');
    const testFile = normalizedComponent.replace(/\.tsx$/, '.test.tsx');

    // Check test file exists
    if (!fs.existsSync(testFile)) {
      violations.push({
        type: 'missing',
        componentPath: normalizedComponent,
        expectedTestPath: testFile,
      });
      console.log(`  ✗ ${normalizedComponent} — missing test file`);
      continue;
    }

    // Run Jest with coverage for this specific file
    try {
      execSync(
        `npx jest --coverage --collectCoverageFrom="${normalizedComponent}" "${testFile}" --passWithNoTests=false`,
        { stdio: 'pipe' }
      );

      // Parse coverage to verify 100%
      const cov = parseCoverage(normalizedComponent);
      if (cov) {
        if (
          cov.lines < 100 ||
          cov.branches < 100 ||
          cov.functions < 100 ||
          cov.statements < 100
        ) {
          violations.push({
            type: 'coverage',
            componentPath: normalizedComponent,
            coverage: cov,
          });
          console.log(`  ✗ ${normalizedComponent} — coverage below 100%`);
        } else {
          console.log(`  ✓ ${normalizedComponent} — 100% coverage`);
        }
      } else {
        console.log(`  ✓ ${normalizedComponent} — tests pass`);
      }
    } catch {
      // Jest failed — determine if tests failed or coverage is insufficient
      const cov = parseCoverage(normalizedComponent);
      const fullCoverage =
        cov !== null &&
        cov.lines === 100 &&
        cov.branches === 100 &&
        cov.functions === 100 &&
        cov.statements === 100;

      if (fullCoverage) {
        violations.push({
          type: 'failing',
          componentPath: normalizedComponent,
        });
        console.log(`  ✗ ${normalizedComponent} — tests FAILING`);
      } else {
        violations.push({
          type: 'coverage',
          componentPath: normalizedComponent,
          coverage: cov || { lines: 0, branches: 0, functions: 0, statements: 0 },
        });
        console.log(`  ✗ ${normalizedComponent} — tests failing / coverage insufficient`);
      }
    }
  }

  console.log('');

  // 3. Report results
  if (violations.length > 0) {
    printViolations(violations);
    process.exit(1);
  }

  console.log(
    'Pre-push TDD Enforcement Passed — All components have tests with 100% coverage.'
  );
  process.exit(0);
}

function printViolations(violations: Violation[]): void {
  console.error(
    '============================================================'
  );
  console.error('  PUSH BLOCKED — TDD ENFORCEMENT FAILED');
  console.error(
    '============================================================'
  );
  console.error('');
  console.error(
    `  ${violations.length} component(s) failed verification:`
  );
  console.error('');

  violations.forEach((v, i) => {
    console.error(`  ${i + 1}. ${v.componentPath}`);
    if (v.type === 'missing') {
      console.error(`     Problem:  Missing test file`);
      console.error(`     Expected: ${v.expectedTestPath}`);
      console.error(`     Fix:      Create the test file with 100% coverage`);
    } else if (v.type === 'failing') {
      console.error(`     Problem:  One or more tests are FAILING`);
      console.error(
        `     Fix:      npx jest ${v.componentPath.replace(/\.tsx$/, '.test.tsx')} --verbose`
      );
    } else {
      console.error(`     Problem:  Coverage below 100%`);
      console.error(
        `     Coverage: Lines ${v.coverage!.lines}% | Branches ${v.coverage!.branches}% | Functions ${v.coverage!.functions}% | Statements ${v.coverage!.statements}%`
      );
      console.error(`     Fix:      Add tests to reach 100% on all metrics`);
    }
    console.error('');
  });

  console.error(
    '  Push blocked. Fix all violations, commit, then push again.'
  );
  console.error(
    '============================================================'
  );
}

main();
