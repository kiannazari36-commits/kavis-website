-- Prompt caching: how many tokens were read from / written to the cache each month (included in input_tokens).
alter table public.usage_monthly
  add column cache_read_tokens  bigint not null default 0,
  add column cache_write_tokens bigint not null default 0;
