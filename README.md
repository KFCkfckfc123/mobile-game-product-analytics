# Mobile Game Product Analytics: A/B Testing and Retention

_Work in progress._

Two analyses of real mobile-game data, written the way a product analytics team would report them:

| Module | Data | Questions |
|---|---|---|
| [`ab-test-cookie-cats/`](ab-test-cookie-cats/) | Cookie Cats A/B test (90,189 players) | Should the first gate move from level 30 to level 40? Includes sample ratio mismatch check, power analysis, bootstrap confidence intervals, and a decision memo. |
| [`retention-flood-it/`](retention-flood-it/) | Flood-It app events in BigQuery (5.7M events, 15,175 users) | How well do new players retain, where do they drop off, and what drives changes in retention? Includes cohort retention, a level-progression funnel, a metric root-cause memo, and an analysis of an in-app experiment. |

This project builds on my [GA4 funnel analysis](https://github.com/KFCkfckfc123/ga4-ecommerce-funnel-analysis). That project measured session-level conversion; this one moves to user-level retention and experimentation on a different product.

## Findings

Findings are added as each stage is completed. Only results from executed code are reported.

### Cookie Cats: data validation (stage 1)

Source: `ab-test-cookie-cats/notebooks/01_ab_test_analysis.ipynb`, sections 1–2.

- **Completeness:** 90,189 rows × 5 columns, matching the dataset description. `userid` is unique (90,189 distinct values) and no column has missing values.
- **Groups:** only two labels exist: `gate_30` (control) = 44,700 players and `gate_40` (treatment) = 45,489 players. Whether this split is consistent with the intended allocation is tested in the sample ratio mismatch check (stage 2).
- **Retention definition:** 3,599 players (4.0%) did not return on day 1 but did return on day 7. So `retention_7` measures activity *on* day 7 (classic day-N retention), not continuous activity through day 7. Overall, before splitting by group: D1 = 44.5%, D7 = 18.6%.
- **Engagement is heavily right-skewed:** median `sum_gamerounds` is 16 and the mean is 51.9; 3,994 players (4.4%) played zero rounds.
- **One extreme outlier:** a `gate_30` player (`userid` 6390605) logged 49,854 rounds in 14 days, about 3,561 rounds per day and 16.8 times the next highest value (2,961). The same player shows no activity on day 1. This is treated as a likely data error:
  - kept in retention analyses, where one player cannot materially change a proportion of ~45,000;
  - excluded from game-round comparisons, which are reported mainly with medians.

### Cookie Cats: sample ratio check and primary metrics (stage 2)

Source: `ab-test-cookie-cats/notebooks/01_ab_test_analysis.ipynb`, section 3. Decision rules were fixed before the results were viewed: SRM threshold p < 0.001; D7 retention as the primary metric and D1 as secondary; two-sided α = 0.05; differences reported as `gate_40 − gate_30`.

- **Sample ratio mismatch (assuming a 50/50 design):** χ² = 6.902, p = 0.0086. This does not cross the pre-set p < 0.001 threshold, so the analysis proceeds. The result is borderline (it would be flagged at 0.05), and the intended allocation is not documented, so the 789-player gap is reported as a caveat.

| Metric | gate_30 (control) | gate_40 (treatment) | Difference | z | p |
|---|---:|---:|---:|---:|---:|
| D7 retention (primary) | 19.02% | 18.20% | −0.82 pp (−4.3% relative) | 3.164 | 0.0016 |
| D1 retention (secondary) | 44.82% | 44.23% | −0.59 pp | 1.784 | 0.074 |

- **Result:** moving the first gate from level 30 to level 40 is associated with a statistically significant drop in D7 retention. The D1 difference points the same way but is not significant at α = 0.05.
- **Not yet established:** the size of the effect with a confidence interval, the test's power, and whether the effect holds across engagement segments. These are covered in stage 3.

## Data sources

- **Cookie Cats:** [Kaggle dataset "Mobile Games A/B Testing - Cookie Cats"](https://www.kaggle.com/datasets/mursideyarkin/mobile-games-ab-testing-cookie-cats), originally from DataCamp; the game is developed by Tactile Entertainment. The dataset page does not state explicit license terms, so the raw CSV is **not** included in this repository. To reproduce, download `cookie_cats.csv` from Kaggle into `ab-test-cookie-cats/data/`.
- **Flood-It:** Google's public BigQuery dataset `firebase-public-project.analytics_153293282` (June 12 to October 3, 2018). All queries are in `retention-flood-it/sql/`; only aggregated results are saved.

## Repository structure

```
ab-test-cookie-cats/
  data/          # place cookie_cats.csv here (not committed)
  notebooks/
  results/
retention-flood-it/
  sql/
  notebooks/
  results/
dashboard/
```

## Setup

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```
