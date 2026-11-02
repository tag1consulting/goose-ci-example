# goose-ci-example

A [Goose](https://github.com/tag1consulting/goose) load test that passes or fails your CI on response times and errors.

Every pull request runs `.github/workflows/load-test.yml`, which:

1. starts a stock Drupal 11.4 site with the Umami demo on the GitHub Actions runner (`site/`) and warms it with one run it does not measure;
2. load tests it with 50 users for 2 minutes, under two pass/fail rules: `--threshold "p95<500ms"` and `--threshold "error-rate<1%"`;
3. uploads the HTML report as the `goose-report` artifact, whether the run passed or failed.

If either rule fails, the job fails and the pull request gets a red cross. Fork it, change the rules or the load test, and point it at your own site.

## What is in here

- `src/`: Goose's [`examples/umami`](https://github.com/tag1consulting/goose/tree/cd4f3cb8ecdabae9504c3189951e43006323605a/examples/umami) load test, copied unchanged from the `release-0.19` branch (see the header of `src/main.rs`). It runs anonymous English and Spanish visitors and an admin who edits articles, and loads each page's CSS, JS and images as a browser would.
- `Cargo.toml` and `Cargo.lock`: the crate, depending on Goose by git at that commit.
- `site/`: `compose.yaml` (MariaDB 11.4 and Drupal 11.4.11, both pinned by digest), `install.sh` (runs `drush site:install demo_umami` in the web container), and `up.sh` (starts the site, waits for it, then runs the unmeasured warm up). A freshly installed Drupal answers some of its first requests with `503` while it generates image derivatives, so the measured run comes after the warm up, as the [example's README](https://github.com/tag1consulting/goose/blob/cd4f3cb8ecdabae9504c3189951e43006323605a/examples/umami/README.md#a-freshly-installed-site) advises.
- `.github/workflows/load-test.yml`: the workflow.

The site exists only on the runner, for the length of one job, and the load test loads nothing else. The passwords in `site/compose.yaml` are for that throwaway site; nothing here needs a secret.

## Run it locally

```bash
./site/up.sh            # needs Docker; set UMAMI_PORT if 8080 is taken
cargo run --release -- --host http://localhost:8080 \
  --users 50 --increase-rate 10 --run-time 2m \
  --quiet --threshold "p95<500ms" --threshold "error-rate<1%" \
  --report-file report.html
echo $?                 # 0 when every rule passed, 1 when one failed
docker compose -f site/compose.yaml down -v
```

## Point it at your own staging site

1. In your repository's **Settings → Secrets and variables → Actions → Variables**, add a variable `STAGING_URL`, such as `https://staging.example.com`.
2. In `.github/workflows/load-test.yml`, delete the "Start Drupal Umami on this runner and warm it up" step, and change `--host "http://localhost:8080"` to `--host "${{ vars.STAGING_URL }}"`.
3. Replace `src/` with a load test of your own site's pages: the Umami one checks for Umami's page titles, so it fails against any other site. The [Goose Book](https://book.goose.rs/) starts with [Creating A Load Test](https://book.goose.rs/getting-started/creating.html).

Only load test a site you are allowed to load test, and warm it first if it has just been deployed.

## How the thresholds fail the build

Each `--threshold` is a rule on the run's metrics. Goose checks every rule once a second while it holds its users steady, and the first rule that fails stops the run. Goose still writes every report, then `GooseAttack::execute()` returns `GooseError::ThresholdsFailed`. Because `main` returns `Result<(), GooseError>`, the program ends with one readable `Error:` line and exits with code 1, which fails the step and the job:

```
[ERROR] threshold p95<1ms failed: observed 354ms at abort, 208ms at end
Error: one or more thresholds failed (p95<1ms, observed 354ms at abort, 208ms at end)
```

(That is a local run with a rule set to fail on purpose.) GitHub Actions then reports `Process completed with exit code 1.`

The report keeps a THRESHOLDS table with each rule, what Goose observed, and whether it passed. The "Keep the report, pass or fail" step runs with `if: always()`, so the report is uploaded either way: open the run's summary page and download `goose-report`.

Rules can judge `pNN` percentiles, `avg`, `max`, `error-rate` and `rps`, for all requests or for one named request. See the Goose Book's [Thresholds](https://book.goose.rs/getting-started/thresholds.html) page for the syntax, when checking starts, and `--no-threshold-abort`.

## Choosing the rules

Rules only mean something against the hardware they run on. These were set from runs on GitHub's `ubuntu-latest` runner, where the load test and the site share one machine; two calibration runs there ([41490045707](https://github.com/tag1consulting/goose-ci-example/actions/runs/41490045707) and [41491483794](https://github.com/tag1consulting/goose-ci-example/actions/runs/41491483794)), at 50 users for 2 minutes, observed a p95 of 5.66 ms and 6.11 ms and an error rate of 0%. `p95<500ms` leaves about 80 times that, and `error-rate<1%` fails on the first few failed requests in a hundred. On your own site, run it a few times first and set the rules from what you see.

## Goose version

Goose 0.19 adds `--threshold`. This example pins Goose by git to [`cd4f3cb8`](https://github.com/tag1consulting/goose/commit/cd4f3cb8ecdabae9504c3189951e43006323605a) on `release-0.19`, which prints that last `Error:` line readably instead of as a Debug dump.

TODO at the 0.19.1 release: switch to `goose = "0.19.1"`.

## License

Apache-2.0; see `LICENSE`. The load test in `src/` is Goose's, under the same license.
