-- Flood-It: why did September new-user retention drop? Diagnosis of a daily export cap.
-- Run in BigQuery. Outputs: retention-flood-it/results/daily_platform_mix.csv (part A)
-- retention-flood-it/results/retention_stable_days.csv (part C), and d1_by_day1_android_share.csv (part D).

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

-- D. Dose-response without a threshold: D1 of new users (installs 2018-07-02 to 10-02) by the Android
--    event share on their day 1, split by platform. If the cap drives the drop, Android users' D1 should
--    rise with that share and iOS users' D1 should not. Wilson CIs computed from users and retained_d1.
WITH mix AS (
  SELECT PARSE_DATE('%Y%m%d', event_date) AS d, COUNTIF(platform = 'ANDROID') / COUNT(*) AS s
  FROM `firebase-public-project.analytics_153293282.events_*`
  GROUP BY d
),
nu AS (
  SELECT user_pseudo_id, first_seen_date AS day0, platform
  FROM `YOUR_PROJECT.flood_it.users`
  WHERE first_touch_date >= '2018-06-12'
    AND DATE_DIFF(first_touch_date, first_seen_date, DAY) BETWEEN -1 AND 1
    AND first_seen_date BETWEEN '2018-07-02' AND '2018-10-02'
),
f AS (
  SELECT nu.platform, m1.s AS s1,
         EXISTS (SELECT 1 FROM `YOUR_PROJECT.flood_it.user_days` AS ud
                 WHERE ud.user_pseudo_id = nu.user_pseudo_id
                   AND ud.activity_date = DATE_ADD(nu.day0, INTERVAL 1 DAY)) AS retained
  FROM nu
  JOIN mix AS m1 ON m1.d = DATE_ADD(nu.day0, INTERVAL 1 DAY)
)
SELECT platform,
       CASE WHEN s1 < 0.2 THEN '<0.20' WHEN s1 < 0.4 THEN '0.20-0.40'
            WHEN s1 < 0.5 THEN '0.40-0.50' ELSE '>=0.50' END AS day1_android_share,
       COUNT(*) AS users, COUNTIF(retained) AS retained_d1,
       ROUND(COUNTIF(retained) / COUNT(*), 4) AS d1_rate
FROM f
GROUP BY platform, day1_android_share
ORDER BY platform, day1_android_share;
-- Threshold sensitivity for part C (September D1, day 0 and day 1 both within the range):
-- 0.50-0.78: 32/143 = 22.4%; 0.40-0.80: 41/206 = 19.9%; >= 0.30: 84/545 = 15.4%. August: 298/1314 = 22.7% in all three.
