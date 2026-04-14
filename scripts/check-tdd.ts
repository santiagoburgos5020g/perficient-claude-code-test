import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

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

function isTddEnabled(): boolean {
  const settingsPath = path.join(__dirname, '..', '.claude', 'settings.json');
  try {
    const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf-8'));
    return settings?.env?.TDD_ENABLED === 'true';
  } catch {
    return false;
  }
}

function main(): void {
  // 0. Check TDD_ENABLED flag
  if (!isTddEnabled()) {
    console.log('TDD Enforcement: Disabled (TDD_ENABLED is not "true" in .claude/settings.json). Skipping checks.');
    process.exit(0);
  }

  // 1. Get staged .tsx files (excluding deleted files)
  let stagedOutput: string;
  try {
    stagedOutput = execSync('git diff --cached --name-only --diff-filter=d')
      .toString()
      .trim();
  } catch {
    console.log('TDD Enforcement: Could not get staged files. Skipping checks.');
    process.exit(0);
  }

  if (!stagedOutput) {
    console.log('TDD Enforcement: No component files staged. Skipping checks.');
    process.exit(0);
  }

  const stagedFiles = stagedOutput.split('\n').filter(Boolean);

  // 2. Filter to component files only
  const componentPattern = /^features\/.*\/components\/.*\.tsx$/;
  const testPattern = /\.(test|spec)\.tsx$/;
  const componentFiles = stagedFiles.filter(
    (f) => componentPattern.test(f.replace(/\\/g, '/')) && !testPattern.test(f)
  );

  // 3. If no component files staged, exit early
  if (componentFiles.length === 0) {
    console.log('TDD Enforcement: No component files staged. Skipping checks.');
    process.exit(0);
  }

  // 4. Check each component
  const violations: Violation[] = [];

  for (const component of componentFiles) {
    const normalizedComponent = component.replace(/\\/g, '/');
    const testFile = normalizedComponent.replace(/\.tsx$/, '.test.tsx');

    // Check test file exists
    if (!fs.existsSync(testFile)) {
      violations.push({
        type: 'missing',
        componentPath: normalizedComponent,
        expectedTestPath: testFile,
      });
      continue;
    }

    // Run Jest with coverage for this specific file
    try {
      execSync(
        `npx jest --coverage --collectCoverageFrom="${normalizedComponent}" "${testFile}" --passWithNoTests=false`,
        { stdio: 'pipe' }
      );

      // Parse coverage to verify 100%
      const coverageSummaryPath = path.join('coverage', 'coverage-summary.json');
      if (fs.existsSync(coverageSummaryPath)) {
        const summary = JSON.parse(fs.readFileSync(coverageSummaryPath, 'utf-8'));
        const resolvedPath = path.resolve(normalizedComponent);
        const fileKey =
          summary[resolvedPath] !== undefined
            ? resolvedPath
            : Object.keys(summary).find(
                (k) => k !== 'total' && path.resolve(k) === resolvedPath
              );

        if (fileKey && summary[fileKey]) {
          const cov = summary[fileKey];
          if (
            cov.lines.pct < 100 ||
            cov.branches.pct < 100 ||
            cov.functions.pct < 100 ||
            cov.statements.pct < 100
          ) {
            violations.push({
              type: 'coverage',
              componentPath: normalizedComponent,
              coverage: {
                lines: cov.lines.pct,
                branches: cov.branches.pct,
                functions: cov.functions.pct,
                statements: cov.statements.pct,
              },
            });
          }
        }
      }
    } catch {
      // Jest failed — determine if tests failed or coverage is insufficient
      const coverageSummaryPath = path.join('coverage', 'coverage-summary.json');
      let coverageData = { lines: 0, branches: 0, functions: 0, statements: 0 };
      let hasCoverage = false;

      if (fs.existsSync(coverageSummaryPath)) {
        try {
          const summary = JSON.parse(
            fs.readFileSync(coverageSummaryPath, 'utf-8')
          );
          const resolvedPath = path.resolve(normalizedComponent);
          const fileKey =
            summary[resolvedPath] !== undefined
              ? resolvedPath
              : Object.keys(summary).find(
                  (k) => k !== 'total' && path.resolve(k) === resolvedPath
                );

          if (fileKey && summary[fileKey]) {
            hasCoverage = true;
            coverageData = {
              lines: summary[fileKey].lines.pct,
              branches: summary[fileKey].branches.pct,
              functions: summary[fileKey].functions.pct,
              statements: summary[fileKey].statements.pct,
            };
          }
        } catch {
          // Could not parse coverage file
        }
      }

      // If coverage is 100% but Jest failed, it means tests are failing
      const fullCoverage =
        hasCoverage &&
        coverageData.lines === 100 &&
        coverageData.branches === 100 &&
        coverageData.functions === 100 &&
        coverageData.statements === 100;

      if (fullCoverage) {
        violations.push({
          type: 'failing',
          componentPath: normalizedComponent,
        });
      } else {
        violations.push({
          type: 'coverage',
          componentPath: normalizedComponent,
          coverage: coverageData,
        });
      }
    }
  }

  // 5. Report results
  if (violations.length > 0) {
    printViolations(violations);
    process.exit(1);
  }

  console.log(
    'TDD Enforcement Passed - All components have tests with 100% coverage.'
  );
  process.exit(0);
}

function printViolations(violations: Violation[]): void {
  console.error(
    '------------------------------------------------------------'
  );
  console.error('  TDD ENFORCEMENT FAILED');
  console.error(
    '------------------------------------------------------------'
  );
  console.error('');

  if (violations.length === 1) {
    const v = violations[0];
    if (v.type === 'missing') {
      console.error('  Missing test file for component:');
      console.error('');
      console.error(`    Component: ${v.componentPath}`);
      console.error(`    Expected:  ${v.expectedTestPath}`);
      console.error('');
      console.error(
        '  Commit blocked. Create the test file with 100% coverage.'
      );
    } else if (v.type === 'failing') {
      console.error('  One or more tests are FAILING for:');
      console.error('');
      console.error(`    Component: ${v.componentPath}`);
      console.error('');
      console.error('  Commit blocked. Fix failing tests before committing.');
      console.error(
        '  Run: npx jest ' +
          v.componentPath.replace(/\.tsx$/, '.test.tsx') +
          ' --verbose'
      );
    } else {
      console.error('  Insufficient test coverage for:');
      console.error('');
      console.error(`    Component: ${v.componentPath}`);
      console.error('');
      console.error('    Coverage Report:');
      console.error(
        `      Lines:      ${v.coverage!.lines}%  (required: 100%)`
      );
      console.error(
        `      Branches:   ${v.coverage!.branches}%  (required: 100%)`
      );
      console.error(
        `      Functions:  ${v.coverage!.functions}%  (required: 100%)`
      );
      console.error(
        `      Statements: ${v.coverage!.statements}%  (required: 100%)`
      );
      console.error('');
      console.error(
        '  Commit blocked. Update tests to achieve 100% coverage.'
      );
    }
  } else {
    console.error(
      `  Found ${violations.length} components with violations:`
    );
    console.error('');
    violations.forEach((v, i) => {
      console.error(`  ${i + 1}. ${v.componentPath}`);
      if (v.type === 'missing') {
        console.error('     -> Missing test file');
      } else if (v.type === 'failing') {
        console.error('     -> Tests are FAILING');
      } else {
        console.error(
          `     -> Coverage: Lines ${v.coverage!.lines}%, ` +
            `Branches ${v.coverage!.branches}%, ` +
            `Functions ${v.coverage!.functions}%, ` +
            `Statements ${v.coverage!.statements}%`
        );
      }
    });
    console.error('');
    console.error(
      '  Commit blocked. Fix all violations before committing.'
    );
  }

  console.error(
    '------------------------------------------------------------'
  );
}

main();
