WITH time_slots AS (
  SELECT generate_series(
    '2021-01-01 00:00:00+00'::timestamptz,
    now(),
    interval '6 hours'
  ) AS transaction_time
),
account_ids AS (
  SELECT generate_series(1000, 1200) AS account_id
)
INSERT INTO bank_statements (account_id, transaction_time, amount, merchant, status)
SELECT
  account_id,
  transaction_time + (random() * interval '6 hours'),
  (random() * 4000 - 2000)::numeric(12,2),
  ('merchant_' || substr(md5(random()::text), 1, 8)),
  (ARRAY['posted', 'pending', 'failed'])[floor(random() * 3 + 1)::int]
FROM time_slots
CROSS JOIN account_ids;
