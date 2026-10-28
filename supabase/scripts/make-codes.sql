-- Davet kodu yapmak (Supabase > SQL Editor'e yapıştır). Kodları sadece sen görürsün.
-- make_promo_codes(kaç tane, kaç gün Premium, en çok kaç kişi kullanır, son kullanma tarihi, not)

-- 10 kişisel kod: her biri 1 kişi, 30 gün Premium
select * from public.make_promo_codes(10, 30, 1, null, 'sınıf arkadaşları');

-- 1 ortak sınıf kodu: 100 kişi kullanabilir, 15 Kasım'a kadar geçerli
-- select * from public.make_promo_codes(1, 30, 100, '2026-11-15 23:59+03', 'Farmakoloji 3. sınıf');

-- Kaç kodu kim kullandı? (used = kullanılan, max_uses = en çok)
-- select code, used, max_uses, days, expires_at, note from public.promo_codes order by created_at desc;

-- Bir kodu kullananlar ve Premium'ları ne zaman bitiyor?
-- select r.code, p.full_name, r.redeemed_at, r.ends_at from public.promo_redemptions r
--   join public.profiles p on p.id = r.user_id order by r.redeemed_at desc;

-- Bir kodu iptal etmek (artık kimse kullanamasın):
-- update public.promo_codes set max_uses = used where code = 'KAVIS-XXXXX';
