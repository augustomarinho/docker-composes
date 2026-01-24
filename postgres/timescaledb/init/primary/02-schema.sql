CREATE TABLE IF NOT EXISTS bank_statements (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  account_id INT NOT NULL,
  transaction_time TIMESTAMPTZ NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  merchant TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('posted', 'pending', 'failed')),
  PRIMARY KEY (id, transaction_time)
);

SELECT create_hypertable(
  'bank_statements',
  'transaction_time',
  chunk_time_interval => interval '30 days',
  if_not_exists => TRUE
);
