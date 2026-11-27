-- Flood-It: day-N retention by install month (cohort = calendar month of day 0) for new installs.
-- Same new-install definition, day-N rule, and right-censoring as 04_pooled_retention.sql.
-- The October cohort (3 days, 173 users) is excluded from the results file as too small and too short.
-- 95% Wilson intervals were computed from eligible_users and retained_users.
-- Output: retention-flood-it/results/retention_by_month.csv

WITH new_users AS (
  SELECT user_pseudo_id, first_seen_date AS day0, DATE_TRUNC(first_seen_date, MONTH) AS cohort_month
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
  LEFT JOIN `YOUR_PROJECT.flood_it.user_days` AS ud
    ON ud.user_pseudo_id = nu.user_pseudo_id
   AND ud.activity_date = DATE_ADD(nu.day0, INTERVAL h.n DAY)
  WHERE nu.day0 <= DATE_SUB(DATE '2018-10-03', INTERVAL h.n DAY)
  GROUP BY nu.cohort_month, h.n, nu.user_pseudo_id
)
SELECT cohort_month, n AS day_n,
       COUNT(*) AS eligible_users,
       COUNTIF(retained) AS retained_users,
       ROUND(COUNTIF(retained) / COUNT(*), 4) AS retention_rate
FROM flags
GROUP BY cohort_month, n
ORDER BY cohort_month, n;

-- Sensitivity check: June D1 split by whether day 1 falls on one of the seven DAU spike days
-- (2018-06-18, 06-19, 06-25, 06-26, 06-28, 06-30, 07-01).
-- Result: 423 users with day 1 on a spike day had D1 = 33.3%; the other 565 June users had 22.7%.
