INSERT INTO user_metadata (user_id, country, tier, signup_unix_ms, tags) VALUES
('u-1',  'US', 'premium',    1704067200000, ARRAY['order-heavy', 'ios']),
('u-2',  'KR', 'basic',      1706745600000, ARRAY['android']),
('u-3',  'JP', 'enterprise', 1709251200000, ARRAY['b2b', 'beta']),
('u-4',  'DE', 'premium',    1711929600000, ARRAY['web']),
('u-5',  'FR', 'basic',      1714521600000, ARRAY['low-touch']),
('u-6',  'KR', 'enterprise', 1717200000000, ARRAY['vip', 'healthcare']),
('u-7',  'US', 'basic',      1719792000000, ARRAY['new-user']),
('u-8',  'JP', 'premium',    1722470400000, ARRAY['coupon-user']),
('u-9',  'DE', 'enterprise', 1725148800000, ARRAY['partner']),
('u-10', 'FR', 'premium',    1727740800000, ARRAY['retention'])
ON CONFLICT (user_id) DO UPDATE SET
    country = EXCLUDED.country,
    tier = EXCLUDED.tier,
    signup_unix_ms = EXCLUDED.signup_unix_ms,
    tags = EXCLUDED.tags,
    updated_at = now();
