-- Kavis Study — example data for development (NOT for production users).
-- Fills one existing account with a realistic pharmacy term so every connected web page shows real rows
-- from the database. Same courses and numbers as the old mock data in web/src/api/mock/courses.ts.
--
-- Re-runnable: it first DELETES that account's courses, lessons, exams, timetable and study sessions,
-- then inserts everything again. Dates are relative to today, so the exams are always "next week".
-- Run it with the service role (Supabase SQL editor or the Supabase MCP connector), never from an app.
--
-- Areas still on mock data (cards, quiz, plan, progress details, notifications, assistant) get their
-- example rows here when they are connected.

do $$
declare
  seed_email constant text := 'kiannazari36@gmail.com';
  uid   uuid;
  c     record;
  m     record;
  cid   uuid;
  mid   uuid;
  n     int;
  i     int;
begin
  select id into uid from auth.users where email = seed_email;
  if uid is null then raise exception 'No account with email %', seed_email; end if;

  -- ── Clean the previous example data of this account ──
  delete from public.study_sessions    where user_id = uid;
  delete from public.timetable_entries where user_id = uid;
  delete from public.exam_periods      where user_id = uid;
  delete from public.courses           where user_id = uid;  -- cascades: course_exams; materials keep course_id null …
  delete from public.materials         where user_id = uid;  -- … so delete them too (cascades: reading_progress, content, …)
  delete from public.user_devices      where user_id = uid and install_id like 'seed-%';

  -- ── Profile and settings ──
  update public.profiles
     set school = 'Ankara Üniversitesi', department = 'Eczacılık', class_year = 4, onboarding_done = true
   where id = uid;
  update public.user_settings
     set study_days = 5, study_hours = 2, plan_mode = 'aim', content_lang = 'pdf', reader_paper = 'sepia'
   where user_id = uid;

  -- ── Midterm week: starts in 4 days ──
  insert into public.exam_periods (user_id, kind, start_date, end_date)
  values (uid, 'midterm', current_date + 4, current_date + 8);

  -- ── Courses (sort order = exam order), one midterm each ──
  for c in
    select * from (values
      (0, 'Farmakoterapi',            null,             'red'::public.course_color),
      (1, 'Toksikoloji',              null,             'amb'),
      (2, 'Farmasötik Teknoloji III', 'Farm. Tek. III', 'vio'),
      (3, 'Farmakognozi',             null,             'grn'),
      (4, 'Farmasötik Kimya II',      null,             'teal')
    ) as v(ord, name, short_name, color)
  loop
    insert into public.courses (user_id, name, short_name, color, language, term, sort_order)
    values (uid, c.name, c.short_name, c.color, 'tr', '2026–2027 Güz', c.ord)
    returning id into cid;

    insert into public.course_exams (user_id, course_id, kind, exam_date, label)
    values (uid, cid, 'midterm', current_date + 4 + c.ord, null);

    -- Lessons (teacher PDFs) of this course: title, pages, % read, minutes studied.
    for m in
      select * from (values
        (0, 'Hipertansiyon',              48,  62, 160),
        (0, 'Diyabet',                    36,   8,  25),
        (0, 'Kalp Yetmezliği',            40, 100, 190),
        (0, 'Astım ve KOAH',              30,  45,  90),
        (1, 'Organofosfat zehirlenmesi',  28,  80, 120),
        (1, 'Parasetamol toksisitesi',    18, 100,  80),
        (1, 'Ağır metaller',              34,  20,  35),
        (2, 'Tablet formülasyonu',        52, 100, 180),
        (2, 'Film kaplama',               26,  55,  70),
        (2, 'Kapsüller',                  22,   0,   0),
        (3, 'Alkaloitler',                44,  70, 110),
        (3, 'Glikozitler',                30,  30,  40),
        (4, 'Beta-laktam antibiyotikler', 38,  15,  30)
      ) as v(course_ord, title, pages, pct, minutes)
      where v.course_ord = c.ord
    loop
      insert into public.materials (user_id, course_id, kind, title, language, page_count, status, processed_at)
      values (uid, cid, 'pdf', m.title, 'tr', m.pages, 'ready', now() - interval '10 days')
      returning id into mid;

      if m.pct > 0 then
        -- updated_at = last time read: Farmakoterapi most recently, then the others.
        insert into public.reading_progress (user_id, material_id, last_page, pages_read, percent_read, finished_at, updated_at)
        values (uid, mid, greatest(1, round(m.pages * m.pct / 100.0)::int),
                array(select generate_series(1, round(m.pages * m.pct / 100.0)::int)),
                m.pct, case when m.pct = 100 then now() - interval '2 days' end,
                now() - make_interval(hours => c.ord * 6 + length(m.title) % 5));
      end if;

      -- Study time: sessions of about 30 minutes, spread over the last 14 evenings.
      n := ceil(m.minutes / 30.0)::int;
      for i in 1..n loop
        insert into public.study_sessions (user_id, course_id, material_id, activity, started_at, ended_at)
        values (uid, cid, mid, 'read',
                (current_date - ((i * 3 + c.ord + length(m.title)) % 14))::timestamp + time '19:00' + make_interval(mins => (i * 17) % 120),
                (current_date - ((i * 3 + c.ord + length(m.title)) % 14))::timestamp + time '19:00' + make_interval(mins => (i * 17) % 120)
                  + make_interval(mins => (m.minutes / n)));
      end loop;
    end loop;
  end loop;

  -- ── Reading page of "Hipertansiyon" (the teacher's text, unchanged), its hard words and saved translations ──
  -- Same shape the server (Edge Function process-material) will write: sections → blocks → paragraphs/segments.
  select id into mid from public.materials where user_id = uid and title = 'Hipertansiyon';
  insert into public.material_content (material_id, user_id, reader_doc, stats)
  values (mid, uid, '{"language":"tr","sections":[{"title":"1 · Tanım","blocks":[{"pageFrom":10,"pageTo":11,"tag":"definition","heading":"Hipertansiyon nedir?","paragraphs":[["Hipertansiyon, tekrarlanan ölçümlerde sistolik kan basıncının 140 mmHg veya diyastolik kan basıncının 90 mmHg ve üzerinde olmasıdır. Vakaların çoğu ",{"term":"t4","text":"primer hipertansiyon"}," grubundadır."],["Sekonder hipertansiyonda ise böbrek hastalığı, endokrin bozukluklar veya bazı ilaçlar gibi belirli bir neden vardır; neden tedavi edilince tansiyon düzelebilir."]]}]},{"title":"2 · İlaç tedavisi","blocks":[{"pageFrom":12,"pageTo":12,"tag":"dose","paragraphs":[["İlk basamak tedavide ",{"term":"t1","text":"Diüretikler"},", ",{"term":"t2","text":"ACE inhibitörleri"},", anjiyotensin reseptör blokerleri (ARB) ve kalsiyum kanal blokerleri kullanılır."],{"selectable":true,"text":"ACE inhibitörlerine düşük dozla başlanır (ör. ramipril 2,5 mg/gün) ve doz 2–4 haftada bir titre edilir."}],"molecule":true},{"pageFrom":13,"pageTo":13,"tag":"side_effect","paragraphs":[["Alfa-1 blokerlerin ilk dozundan sonra ",{"term":"t3","text":"Ortostatik hipotansiyon"}," görülebilir; ilk dozun yatmadan önce alınması önerilir."]],"audio":true}]},{"title":"3 · Özel durumlar","blocks":[{"pageFrom":14,"pageTo":15,"tag":"special","heading":"Özel durumlar","paragraphs":[["Gebelikte metildopa, labetalol ve nifedipin tercih edilir. ACE inhibitörleri ve ARB''ler fetüse zarar verdiği için gebelikte ",{"term":"t6","text":"kontrendike"},"dir."],["Diyabetik hastalarda böbreği koruduğu için ilk seçenek ACE inhibitörü veya ARB''dir. Yaşlılarda düşük dozla başlanır ve ortostatik hipotansiyon açısından izlenir."]]}]},{"title":"4 · Hipertansif kriz","blocks":[{"pageFrom":16,"pageTo":16,"tag":"emergency","heading":"Hipertansif kriz","paragraphs":[["Kan basıncı 180/120 mmHg''nin üzerindeyse ve ",{"term":"t7","text":"hedef organ hasarı"}," varsa hipertansif acil durum vardır; tansiyon damar yoluyla ilaçla, ilk saatte en fazla %25 düşürülür."],["Organ hasarı yoksa (hipertansif ivedi durum) tansiyon ağızdan alınan ilaçlarla 24–48 saat içinde yavaşça düşürülür. Çok hızlı düşürmek beyin ve kalbe zarar verebilir."]]}]}]}'::jsonb, '{"pages": 48, "terms": 6}');

  -- Hard words: explanation per app language = { name, kind, text }.
  insert into public.material_terms (material_id, user_id, term_key, surface, page, explanation)
  select mid, uid, v.k, v.surface, v.page, v.expl
  from (values
      ('t1', 'Diüretikler', 12, '{"tr":{"name":"Diüretikler","kind":"İlaç grubu","text":"Böbreklerden tuz ve su atılımını artırarak kan hacmini ve tansiyonu düşüren ilaçlar (ör. tiyazidler)."},"en":{"name":"Diuretics","kind":"Drug group","text":"Drugs that lower blood volume and blood pressure by increasing salt and water excretion by the kidneys (e.g. thiazides)."},"fa":{"name":"دیورتیک‌ها","kind":"گروه دارویی","text":"داروهایی که با افزایش دفع نمک و آب از کلیه‌ها، حجم خون و فشار خون را پایین می‌آورند (مثلاً تیازیدها)."},"ar":{"name":"مدرات البول","kind":"المجموعة الدوائية","text":"أدوية تخفض حجم الدم وضغط الدم بزيادة إطراح الملح والماء عبر الكلى (مثل الثيازيدات)."}}'::jsonb),
      ('t2', 'ACE inhibitörleri', 12, '{"tr":{"name":"ACE inhibitörleri","kind":"İlaç grubu","text":"Anjiyotensin I''in anjiyotensin II''ye dönüşümünü engelleyen ilaçlar. Damar daralmasını ve aldosteronu azaltır. Örnek: kaptopril, ramipril."},"en":{"name":"ACE inhibitors","kind":"Drug group","text":"Drugs that block conversion of angiotensin I to angiotensin II. They reduce vasoconstriction and aldosterone. Examples: captopril, ramipril."},"fa":{"name":"مهارکننده‌های ACE","kind":"گروه دارویی","text":"داروهایی که تبدیل آنژیوتانسین I به آنژیوتانسین II را مهار می‌کنند. تنگی رگ و آلدوسترون را کاهش می‌دهند. مثال: کاپتوپریل، رامی‌پریل."},"ar":{"name":"مثبطات ACE","kind":"المجموعة الدوائية","text":"أدوية تمنع تحويل الأنجيوتنسين I إلى الأنجيوتنسين II. تقلل تضيق الأوعية والألدوستيرون. أمثلة: كابتوبريل، راميبريل."}}'::jsonb),
      ('t3', 'Ortostatik hipotansiyon', 13, '{"tr":{"name":"Ortostatik hipotansiyon","kind":"Yan etki","text":"Ayağa kalkınca tansiyonun birden düşmesi; baş dönmesi ve bayılma yapabilir."},"en":{"name":"Orthostatic hypotension","kind":"Side effect","text":"Blood pressure drops suddenly when you stand up; can cause dizziness and fainting."},"fa":{"name":"افت فشار خون وضعیتی","kind":"عارضه جانبی","text":"فشار خون هنگام ایستادن ناگهان افت می‌کند؛ می‌تواند سرگیجه و غش ایجاد کند."},"ar":{"name":"هبوط الضغط الانتصابي","kind":"أثر جانبي","text":"ينخفض الضغط فجأة عند الوقوف؛ وقد يسبب دوخة وإغماء."}}'::jsonb),
      ('t4', 'primer hipertansiyon', 10, '{"tr":{"name":"Primer hipertansiyon","kind":"Tanım","text":"Belirli bir nedeni bulunamayan hipertansiyon. Hastaların büyük çoğunluğu bu gruptadır; esansiyel hipertansiyon da denir."},"en":{"name":"Primary hypertension","kind":"Definition","text":"Hypertension with no identifiable cause. Most patients are in this group; also called essential hypertension."},"fa":{"name":"فشار خون اولیه","kind":"تعریف","text":"فشار خون بالایی که علت مشخصی برایش پیدا نمی‌شود. بیشتر بیماران در این گروه‌اند؛ به آن فشار خون اساسی هم می‌گویند."},"ar":{"name":"ارتفاع ضغط الدم الأولي","kind":"التعريف","text":"ارتفاع ضغط الدم الذي لا يُعرف له سبب محدد. معظم المرضى في هذه المجموعة؛ ويُسمى أيضاً ارتفاع ضغط الدم الأساسي."}}'::jsonb),
      ('t6', 'kontrendike', 14, '{"tr":{"name":"Kontrendike","kind":"Kavram","text":"Bir ilacın o hastada ya da o durumda kullanılmaması gerektiği anlamına gelir; zararı yararından fazladır."},"en":{"name":"Contraindicated","kind":"Concept","text":"Means a drug should not be used in that patient or situation; its harm outweighs its benefit."},"fa":{"name":"منع مصرف دارد","kind":"مفهوم","text":"یعنی دارو نباید در آن بیمار یا آن شرایط مصرف شود؛ ضررش از فایده‌اش بیشتر است."},"ar":{"name":"مضاد استطباب","kind":"مفهوم","text":"يعني أن الدواء لا يجب استخدامه لدى ذلك المريض أو في تلك الحالة؛ ضرره أكبر من نفعه."}}'::jsonb),
      ('t7', 'hedef organ hasarı', 16, '{"tr":{"name":"Hedef organ hasarı","kind":"Kavram","text":"Yüksek tansiyonun beyin, kalp, böbrek veya gözde yaptığı akut hasar (ör. inme, kalp yetmezliği, böbrek yetmezliği)."},"en":{"name":"Target organ damage","kind":"Concept","text":"Acute damage high blood pressure causes to the brain, heart, kidneys or eyes (e.g. stroke, heart failure, kidney failure)."},"fa":{"name":"آسیب اندام هدف","kind":"مفهوم","text":"آسیب حادی که فشار خون بالا به مغز، قلب، کلیه یا چشم می‌زند (مثلاً سکته مغزی، نارسایی قلبی، نارسایی کلیه)."},"ar":{"name":"تلف الأعضاء المستهدفة","kind":"مفهوم","text":"الضرر الحاد الذي يسببه ارتفاع ضغط الدم للدماغ أو القلب أو الكلى أو العين (مثل السكتة الدماغية، قصور القلب، الفشل الكلوي)."}}'::jsonb)
  ) as v(k, surface, page, expl);

  -- Translations of one sentence (source_hash = sha256 of the sentence), literal and natural.
  insert into public.translations (material_id, user_id, source_hash, target_lang, style, text)
  select mid, uid, encode(sha256(convert_to('İlk basamak tedavide Diüretikler, ACE inhibitörleri, anjiyotensin reseptör blokerleri (ARB) ve kalsiyum kanal blokerleri kullanılır.', 'UTF8')), 'hex'), v.l::public.app_lang, v.s::public.translation_style, v.t
  from (values
      ('en', 'literal', 'First-line treatment Diuretics, ACE inhibitors, angiotensin receptor blockers (ARB) and calcium channel blockers are used.'),
      ('en', 'natural', 'For first-line treatment, four drug groups are used: diuretics, ACE inhibitors, angiotensin receptor blockers (ARBs) and calcium channel blockers.'),
      ('fa', 'literal', 'در درمان خط اول دیورتیک‌ها، مهارکننده‌های ACE، مسدودکننده‌های گیرنده آنژیوتانسین (ARB) و مسدودکننده‌های کانال کلسیم استفاده می‌شوند.'),
      ('fa', 'natural', 'برای شروع درمان، چهار گروه دارو به کار می‌رود: دیورتیک‌ها، مهارکننده‌های ACE، داروهای ARB و مسدودکننده‌های کانال کلسیم.'),
      ('ar', 'literal', 'في العلاج من الخط الأول تُستخدم مدرات البول، مثبطات ACE، حاصرات مستقبلات الأنجيوتنسين (ARB) وحاصرات قنوات الكالسيوم.'),
      ('ar', 'natural', 'في بداية العلاج نستخدم أربع مجموعات من الأدوية: مدرات البول، ومثبطات ACE، وحاصرات مستقبلات الأنجيوتنسين، وحاصرات قنوات الكالسيوم.')
  ) as v(l, s, t);

  -- ── School timetable (Monday = 1) ──
  insert into public.timetable_entries (user_id, course_id, title, weekday, start_time, end_time, room, teacher)
  select uid, co.id, t.title, t.weekday, t.start_time, t.end_time, t.room, t.teacher
  from (values
    ('Farmakoterapi',            'Farmakoterapi',            1, time '09:00', time '10:50', 'Amfi 3',  'Prof. Dr. S. Aydın'),
    ('Toksikoloji',              'Toksikoloji',              2, time '10:00', time '11:50', 'Amfi 1',  'Doç. Dr. M. Kaya'),
    ('Farmasötik Teknoloji III', 'Farm. Tek. III Lab',       3, time '13:00', time '16:50', 'Lab 2',   'Dr. Öğr. Üyesi A. Demir'),
    ('Farmakognozi',             'Farmakognozi',             4, time '09:00', time '10:50', 'Amfi 2',  'Prof. Dr. N. Şahin'),
    ('Farmasötik Kimya II',      'Farmasötik Kimya II',      5, time '11:00', time '12:50', 'Amfi 3',  'Doç. Dr. E. Yılmaz')
  ) as t(course_name, title, weekday, start_time, end_time, room, teacher)
  join public.courses co on co.user_id = uid and co.name = t.course_name;

  -- ── Devices: an iPhone used yesterday (the web registers itself at login; max 2 devices) ──
  insert into public.user_devices (user_id, install_id, kind, name, app_version, last_seen_at)
  values (uid, 'seed-iphone', 'iphone', 'iPhone 15', '1.0', date_trunc('minute', now() - interval '1 day 2 hours'));

  -- Inserting 13 lessons raised the trial and monthly counters (database triggers). Example data should not
  -- use up the trial: count one lesson, like a student who uploaded one PDF so far.
  update public.materials set counted_in_trial = false where user_id = uid;
  -- 23 of 60 assistant questions used.
  insert into public.trial_usage (user_id, lessons, assistant_questions) values (uid, 1, 23)
    on conflict (user_id) do update set lessons = 1, assistant_questions = 23;
  delete from public.usage_monthly where user_id = uid;
end $$;
