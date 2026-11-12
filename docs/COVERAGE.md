# Code Coverage Guide

Quick reference for code coverage analysis in the YUP application template.

## Quick Start

```bash
# 1. Install lcov
sudo apt-get install lcov  # Linux
brew install lcov          # macOS

# 2. Configure with coverage
cmake -B build -DCMAKE_BUILD_TYPE=Debug -DENABLE_COVERAGE=ON

# 3. Build
cmake --build build --config Debug

# 4. Run tests
cd build && ctest --output-on-failure

# 5. Generate coverage report
make coverage

# 6. Generate HTML report
make coverage_html
open coverage/html/index.html  # macOS
xdg-open coverage/html/index.html  # Linux
```

## What is Code Coverage?

Code coverage measures which lines of code are executed when tests run. It helps:
- Identify untested code paths
- Find dead code
- Ensure critical code is tested
- Track testing progress

## Coverage Targets

| Target | Description |
|--------|-------------|
| `coverage_clean` | Clean old coverage data |
| `coverage` | Generate lcov coverage report |
| `coverage_html` | Generate browsable HTML report |

## Workflow

### First Time Setup

```bash
# Install dependencies (one time)
sudo apt-get install lcov  # Linux
brew install lcov          # macOS

# Create coverage build
cmake -B build-coverage \
  -DCMAKE_BUILD_TYPE=Debug \
  -DENABLE_COVERAGE=ON
```

### Regular Usage

```bash
cd build-coverage

# Clean old data
make coverage_clean

# Build and run tests
cmake --build . && ctest

# Generate report
make coverage

# View detailed HTML report
make coverage_html
open coverage/html/index.html
```

### After Code Changes

```bash
cd build-coverage

# Rebuild
cmake --build .

# Clean coverage data
make coverage_clean

# Run tests
ctest --output-on-failure

# Update report
make coverage
make coverage_html
```

## Understanding the Report

### Terminal Output

After `make coverage`, you'll see:
```
                                 |Lines      |Functions
Filename                         |Rate    Num|Rate    Num
=============================================================
source/Application.cpp           | 87.5%    32| 100.0%   4
source/MainWindow.cpp            | 92.3%    65|  90.0%  10
=============================================================
                          TOTAL  | 89.2%    97|  92.5%  14
```

### HTML Report

The HTML report (`coverage/html/index.html`) shows:
- **Directory view**: Coverage by directory
- **File view**: Coverage for each file
- **Line view**: Line-by-line execution
  - Green: Executed
  - Red: Not executed
  - Orange: Partially executed (branches)

## Coverage Metrics

### Line Coverage
Percentage of lines executed:
- **Good**: 70-80%
- **Excellent**: 85%+
- **Outstanding**: 90%+

### Function Coverage
Percentage of functions called:
- Should typically be high (80%+)

### Branch Coverage
Percentage of conditional branches taken:
- Tests both `if` and `else` paths
- Most important for complex logic

## Best Practices

### Do:
✓ Test critical code paths first
✓ Aim for 80%+ coverage on core logic
✓ Test edge cases and error handling
✓ Review uncovered code regularly
✓ Use coverage to guide testing efforts

### Don't:
✗ Chase 100% coverage blindly
✗ Test generated/template code
✗ Write tests just for coverage
✗ Ignore quality for quantity
✗ Test trivial getters/setters

## CI/CD Integration

### GitHub Actions

The `.github/workflows/coverage.yml` workflow:
1. Runs on push/pull request
2. Builds with coverage enabled
3. Runs all tests
4. Generates coverage report
5. Uploads to Codecov
6. Comments on PRs with coverage changes

### Setup Codecov

1. Sign up at https://codecov.io
2. Connect your repository
3. Add `CODECOV_TOKEN` secret:
   - GitHub repo → Settings → Secrets → Actions
   - New secret: `CODECOV_TOKEN`

4. Add badge to README.md:
```markdown
[![codecov](https://codecov.io/gh/username/repo/branch/main/graph/badge.svg)](https://codecov.io/gh/username/repo)
```

### Codecov Configuration

Edit `codecov.yml` to customize:
```yaml
coverage:
  status:
    project:
      default:
        target: 80%      # Change target
        threshold: 5%    # Allow 5% decrease
```

## Troubleshooting

### Problem: "lcov not found"

**Solution:**
```bash
# Linux
sudo apt-get update
sudo apt-get install lcov

# macOS
brew install lcov
```

### Problem: No coverage data generated

**Checklist:**
- [ ] `-DENABLE_COVERAGE=ON` was used
- [ ] Debug build (`-DCMAKE_BUILD_TYPE=Debug`)
- [ ] Tests were run (`ctest`)
- [ ] Using GCC or Clang (not MSVC)

**Verify:**
```bash
# Check for .gcda files
find build -name "*.gcda"

# Should show coverage files after running tests
```

### Problem: Coverage shows 0%

**Common causes:**
1. Tests didn't run: `ctest --output-on-failure`
2. Wrong compiler: Verify `echo $CXX` shows g++ or clang++
3. Build mismatch: Clean and rebuild

**Solution:**
```bash
rm -rf build
cmake -B build -DCMAKE_BUILD_TYPE=Debug -DENABLE_COVERAGE=ON
cmake --build build
cd build && ctest && make coverage
```

### Problem: Missing coverage for specific files

**Likely:**
- File is not executed by any test
- File is in ignored paths (tests/, build/, etc.)

**Check:**
```bash
# View all coverage data
lcov --list build/coverage/coverage_final.info
```

### Problem: "Cannot merge" errors

**Solution:**
```bash
# Clean all coverage data
find build -name "*.gcda" -delete
lcov --directory build --zerocounters
```

## Advanced Usage

### Coverage for Specific Tests

```bash
# Run only specific tests
cd build
ctest -R "TestName" --output-on-failure
make coverage
```

### Compare Coverage

```bash
# Generate baseline
make coverage
cp coverage/coverage_final.info coverage/baseline.info

# Make changes, run tests again
make coverage_clean
ctest
make coverage

# Compare
lcov --diff coverage/baseline.info coverage/coverage_final.info
```

### Manual Coverage Generation

```bash
cd build

# Capture coverage
lcov --directory . --capture --output-file coverage.info

# Filter unwanted files
lcov --remove coverage.info \
  "*/tests/*" "*/usr/*" "*/_deps/*" \
  --output-file coverage_filtered.info

# Generate HTML
genhtml coverage_filtered.info \
  --output-directory coverage_html \
  --title "My App Coverage"
```

## Tips

1. **Clean data between runs**: Always run `make coverage_clean` before new tests
2. **Use Debug builds**: Optimizations can affect coverage accuracy
3. **Review regularly**: Check coverage after adding new code
4. **Focus on logic**: Prioritize coverage of complex algorithms
5. **Combine with profiling**: Find hot paths that need testing
6. **Track trends**: Monitor coverage over time, not just current value

## Further Reading

- [lcov documentation](http://ltp.sourceforge.net/coverage/lcov.php)
- [Codecov documentation](https://docs.codecov.com/)
- [gcov documentation](https://gcc.gnu.org/onlinedocs/gcc/Gcov.html)
- See also: `CONFIGURATION.md` for detailed setup

## Summary Commands

```bash
# One-liner: Full coverage workflow
cmake -B build -DCMAKE_BUILD_TYPE=Debug -DENABLE_COVERAGE=ON && \
  cmake --build build && \
  cd build && make coverage_clean && ctest && make coverage_html

# Quick check: Just coverage percentage
cd build && make coverage | grep "TOTAL"

# CI simulation: What CI runs
cmake -B build -DCMAKE_BUILD_TYPE=Debug -DENABLE_COVERAGE=ON
cmake --build build --target template_tests
cd build && ctest --output-on-failure
make coverage
```
