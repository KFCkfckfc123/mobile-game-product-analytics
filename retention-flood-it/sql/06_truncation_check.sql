-- Flood-It: why did September new-user retention drop? Diagnosis of a daily export cap.
-- Run in BigQuery. Outputs: retention-flood-it/results/daily_platform_mix.csv (part A)
-- and retention-flood-it/results/retention_stable_days.csv (part C).

-- A. Every daily table in the export holds exactly 50,000 events (114 of 114 days).
--    Android and iOS share that fixed budget, so on days when one platform's share collapses,
--    its active users disappear from the data.
SELECT PARSE_DATE('%Y%m%d', event_date) AS date,
       COUNT(*) AS events,
       COUNTIF(platform = 'ANDROID') AS android_events,
       COUNTIF(platform = 'IOS') AS ios_events,
       COUNT(DISTINCT IF(platform = 'ANDROID', user_pseudo_id, NULL)) AS android_users,
       COUNT(DISTINCT IF(platform = 'IOS', user_pseudo_id, NULL)) AS ios_users,
       ROUND(COUNTIF(platform = 'ANDROID') / COUNT(*), 4) AS android_event_share
FROM `firebase-public-project.analytics_153293282.events_*`
GROUP BY date
ORDER BY date;

-- B. Established users (first seen 14+ days earlier) returned the next day at 44-48% per week in August,
--    falling to 34% (week of 9/3) and 25% (week of 9/10). A drop that hits existing users at the same
--    time as new users points to measurement, not onboarding.
WITH old AS (
  SELECT ud.user_pseudo_id, ud.activity_date AS d
  FROM `YOUR_PROJECT.flood_it.user_days` AS ud
  JOIN `YOUR_PROJECT.flood_it.users` AS u USING (user_pseudo_id)
  WHERE DATE_DIFF(ud.activity_date, u.first_seen_date, DAY) >= 14
)
SELECT DATE_TRUNC(o.d, WEEK(MONDAY)) AS week, COUNT(*) AS user_days,
       ROUND(COUNTIF(n.user_pseudo_id IS NOT NULL) / COUNT(*), 3) AS next_day_return
FROM old AS o
LEFT JOIN `YOUR_PROJECT.flood_it.user_days` AS n
  ON n.user_pseudo_id = o.user_pseudo_id AND n.activity_date = DATE_ADD(o.d, INTERVAL 1 DAY)
GROUP BY week
ORDER BY week;

-- C. Retention restricted to "stable" days: Android event share within 0.50-0.78, the range observed on
--    every day from 2018-07-02 to 2018-09-01. A user counts toward day N only if both day 0 and day N
--    are stable days. Same new-install definition and right-censoring as 04/05.
WITH day_mix AS (
  SELECT PARSE_DATE('%Y%m%d', event_date) AS d,
         COUNTIF(platform = 'ANDROID') / COUNT(*) BETWEEN 0.50 AND 0.78 AS stable
  FROM `firebase-public-project.analytics_153293282.events_*`
  GROUP BY d
),
new_users AS (
  SELECT user_pseudo_id, first_seen_date AS day0, FORMAT_DATE('%Y-%m', first_seen_date) AS cohort_month
  FROM `YOUR_PROJECT.flood_it.users`
  WHERE first_touch_date >= '2018-06-12'
    AND DATE_DIFF(first_touch_date, first_seen_date, DAY) BETWEEN -1 AND 1
),
horizons AS (SELECT n FROM UNNEST([1, 7, 14, 30]) AS n),
flags AS (
  SELECT nu.cohort_month, h.n, nu.user_pseudo_id,
         LOGICAL_OR(ud.activity_date IS NOT NULL) AS retained
  FROM new_users AS nu
  CROSS JOIN horizons AS h
  JOIN day_mix AS m0 ON m0.d = nu.day0 AND m0.stable
  JOIN day_mix AS mn ON mn.d = DATE_ADD(nu.day0, INTERVAL h.n DAY) AND mn.stable
  LEFT JOIN `YOUR_PROJECT.flood_it.user_days` AS ud
    ON ud.user_pseudo_id = nu.user_pseudo_id
   AND ud.activity_date = DATE_ADD(nu.day0, INTERVAL h.n DAY)
  WHERE nu.day0 <= DATE_SUB(DATE '2018-10-03', INTERVAL h.n DAY)
  GROUP BY nu.cohort_month, h.n, nu.user_pseudo_id
)
SELECT 'all' AS cohort_month, n AS day_n, COUNT(*) AS eligible_users, COUNTIF(retained) AS retained_users,
       ROUND(COUNTIF(retained) / COUNT(*), 4) AS retention_rate
FROM flags GROUP BY n
UNION ALL
SELECT cohort_month, n, COUNT(*), COUNTIF(retained), ROUND(COUNTIF(retained) / COUNT(*), 4)
FROM flags GROUP BY cohort_month, n
ORDER BY cohort_month, day_n;
