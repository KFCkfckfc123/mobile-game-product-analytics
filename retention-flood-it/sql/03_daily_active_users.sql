-- Flood-It: DAU, WAU, MAU, and stickiness (DAU / MAU) for every day in the export.
-- Uses all users in user_days (no install-date restriction).
-- Active = at least one logged event on that date.
-- WAU is reported from 2018-06-18 and MAU from 2018-07-11, the first days with a full
-- 7- and 30-day look-back inside the export. Earlier values would be undercounted.
-- Output: retention-flood-it/results/daily_active_users.csv

WITH days AS (
  SELECT day FROM UNNEST(GENERATE_DATE_ARRAY('2018-06-12', '2018-10-03')) AS day
),
daily AS (
  SELECT
    d.day,
    COUNT(DISTINCT IF(u.activity_date = d.day, u.user_pseudo_id, NULL)) AS dau,
    COUNT(DISTINCT IF(u.activity_date >= DATE_SUB(d.day, INTERVAL 6 DAY), u.user_pseudo_id, NULL)) AS wau,
    COUNT(DISTINCT u.user_pseudo_id) AS mau
  FROM days AS d
  JOIN `YOUR_PROJECT.flood_it.user_days` AS u
    ON u.activity_date BETWEEN DATE_SUB(d.day, INTERVAL 29 DAY) AND d.day
  GROUP BY d.day
)
SELECT
  day AS date,
  dau,
  IF(day >= '2018-06-18', wau, NULL) AS wau,
  IF(day >= '2018-07-11', mau, NULL) AS mau,
  IF(day >= '2018-07-11', ROUND(dau / mau, 4), NULL) AS dau_mau
FROM daily
ORDER BY day;
