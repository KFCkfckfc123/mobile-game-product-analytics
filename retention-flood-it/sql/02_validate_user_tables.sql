-- Flood-It: validation checks on the base tables. Each query is cheap (< 3 MB scanned).

-- 1. Row counts, uniqueness, date ranges, missing attributes.
SELECT COUNT(*) AS users, COUNT(DISTINCT user_pseudo_id) AS distinct_users,
       MIN(first_seen_date) AS min_seen, MAX(first_seen_date) AS max_seen,
       COUNTIF(first_touch_date IS NULL) AS null_first_touch,
       COUNTIF(first_touch_date < '2018-06-12') AS touched_before_window,
       COUNTIF(platform IS NULL) AS null_platform,
       COUNTIF(country IS NULL OR country = '') AS null_country
FROM `YOUR_PROJECT.flood_it.users`;

-- 2. user_days: no duplicate user-day rows, 114 distinct days.
SELECT COUNT(*) AS user_day_rows, COUNT(DISTINCT user_pseudo_id) AS users,
       COUNT(DISTINCT activity_date) AS days,
       MIN(activity_date) AS min_day, MAX(activity_date) AS max_day,
       COUNT(*) - COUNT(DISTINCT FORMAT('%s|%t', user_pseudo_id, activity_date)) AS duplicate_rows
FROM `YOUR_PROJECT.flood_it.user_days`;

-- 3. When did users first open the app, relative to the export window?
SELECT EXTRACT(YEAR FROM first_touch_date) AS touch_year, COUNT(*) AS users
FROM `YOUR_PROJECT.flood_it.users`
WHERE first_touch_date < '2018-06-12'
GROUP BY 1 ORDER BY 1;

-- 4. For users who first opened the app inside the window: gap between first open and first logged event.
SELECT DATE_DIFF(first_touch_date, first_seen_date, DAY) AS touch_minus_seen, COUNT(*) AS users
FROM `YOUR_PROJECT.flood_it.users`
WHERE first_touch_date >= '2018-06-12'
GROUP BY 1 ORDER BY 1;
