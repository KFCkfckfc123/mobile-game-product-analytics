-- Flood-It: build the two base tables used by every retention query.
-- Source: firebase-public-project.analytics_153293282.events_* (2018-06-12 to 2018-10-03).
-- Replace YOUR_PROJECT with your own GCP project ID. Estimated scan: ~495 MB + ~251 MB.

CREATE SCHEMA IF NOT EXISTS `YOUR_PROJECT.flood_it` OPTIONS (location = 'US');

-- One row per user: first activity date in the export, first-open date, and first-event attributes.
CREATE OR REPLACE TABLE `YOUR_PROJECT.flood_it.users` AS
SELECT
  user_pseudo_id,
  MIN(PARSE_DATE('%Y%m%d', event_date))                   AS first_seen_date,
  DATE(TIMESTAMP_MICROS(MIN(user_first_touch_timestamp))) AS first_touch_date,
  ARRAY_AGG(STRUCT(platform, geo.country AS country, app_info.version AS app_version)
            ORDER BY event_timestamp LIMIT 1)[OFFSET(0)].*
FROM `firebase-public-project.analytics_153293282.events_*`
GROUP BY user_pseudo_id;

-- One row per user per active day.
CREATE OR REPLACE TABLE `YOUR_PROJECT.flood_it.user_days` AS
SELECT DISTINCT user_pseudo_id, PARSE_DATE('%Y%m%d', event_date) AS activity_date
FROM `firebase-public-project.analytics_153293282.events_*`;
