-- Flood-It: pooled day-N retention (D1, D7, D14, D30) for new installs.
-- New installs: first_touch_date inside the export window and within one day of first logged activity
-- (5,152 users; see 02_validate_user_tables.sql). Day 0 = first logged activity.
-- Day-N retention = active on exactly day 0 + N (classic day-N retention, same definition as the Cookie Cats module).
-- Right-censoring: a user counts toward day N only if day 0 + N is on or before 2018-10-03.
-- 95% Wilson intervals were computed from eligible_users and retained_users.
-- Output: retention-flood-it/results/retention_pooled.csv

WITH new_users AS (
  SELECT user_pseudo_id, first_seen_date AS day0
  FROM `YOUR_PROJECT.flood_it.users`
  WHERE first_touch_date >= '2018-06-12'
    AND DATE_DIFF(first_touch_date, first_seen_date, DAY) BETWEEN -1 AND 1
),
horizons AS (SELECT n FROM UNNEST([1, 7, 14, 30]) AS n),
flags AS (
  SELECT h.n, nu.user_pseudo_id,
         LOGICAL_OR(ud.activity_date IS NOT NULL) AS retained
  FROM new_users AS nu
  CROSS JOIN horizons AS h
  LEFT JOIN `YOUR_PROJECT.flood_it.user_days` AS ud
    ON ud.user_pseudo_id = nu.user_pseudo_id
   AND ud.activity_date = DATE_ADD(nu.day0, INTERVAL h.n DAY)
  WHERE nu.day0 <= DATE_SUB(DATE '2018-10-03', INTERVAL h.n DAY)
  GROUP BY h.n, nu.user_pseudo_id
)
SELECT n AS day_n,
       COUNT(*) AS eligible_users,
       COUNTIF(retained) AS retained_users,
       ROUND(COUNTIF(retained) / COUNT(*), 4) AS retention_rate
FROM flags
GROUP BY n
ORDER BY n;
