# Mobile Game Product Analytics: A/B Testing and Retention

_Work in progress._

Two analyses of real mobile-game data, written the way a product analytics team would report them:

| Module | Data | Questions |
|---|---|---|
| [`ab-test-cookie-cats/`](ab-test-cookie-cats/) | Cookie Cats A/B test (90,189 players) | Should the first gate move from level 30 to level 40? Includes sample ratio mismatch check, power analysis, bootstrap confidence intervals, and a decision memo. |
| [`retention-flood-it/`](retention-flood-it/) | Flood-It app events in BigQuery (5.7M events, 15,175 users) | How well do new players retain, where do they drop off, and what drives changes in retention? Includes cohort retention, a level-progression funnel, a metric root-cause memo, and an analysis of an in-app experiment. |

This project builds on my [GA4 funnel analysis](https://github.com/KFCkfckfc123/ga4-ecommerce-funnel-analysis). That project measured session-level conversion; this one moves to user-level retention and experimentation on a different product.

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
