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
  qid   uuid;
  qid2  uuid;
  pid   uuid;
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
  delete from public.study_plans       where user_id = uid;
  delete from public.review_sessions   where user_id = uid;

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

  -- ── Flash cards (made by the server from the lesson; the app only updates the review state) ──
  -- due: 'now' = in today's round; a number = days from now (already reviewed once, "Knew it").
  for m in
    select * from (values
      ('Hipertansiyon', 'Tiyazid diüretiklerin zorunlu kontrendikasyonu nedir?', 'Gut', 'Tiyazidler serum ürik asit düzeyini artırır.', 14, 'now'),
      ('Hipertansiyon', 'Alfa-1 blokerlerin ilk dozundan sonra ne görülebilir?', 'Ortostatik hipotansiyon', 'Bu yüzden ilk dozun yatmadan önce alınması önerilir.', 13, 'now'),
      ('Hipertansiyon', 'ACE inhibitörlerine bağlı kuru öksürük neyin birikimiyle ilişkilidir?', 'Bradikinin', 'ACE inhibitörleri nadiren anjiyoödem de yapabilir.', 13, 'now'),
      ('Hipertansiyon', 'Hipertansiyon tanısı için sınır değerler nelerdir?', 'Sistolik ≥ 140 mmHg veya diyastolik ≥ 90 mmHg', 'Tek ölçüm yetmez; tekrarlanan ölçümlerde bulunmalıdır.', 10, 'now'),
      ('Hipertansiyon', 'Belirli bir nedeni bulunamayan hipertansiyona ne denir?', 'Primer (esansiyel) hipertansiyon', 'Hastaların büyük çoğunluğu bu gruptadır.', 10, 'now'),
      ('Hipertansiyon', 'İlk basamak tedavide kullanılan dört ilaç grubu hangileridir?', 'Diüretikler, ACE inhibitörleri, ARB''ler, kalsiyum kanal blokerleri', null, 12, 'now'),
      ('Hipertansiyon', 'ACE inhibitörü tedavisine nasıl başlanır?', 'Düşük dozla (ör. ramipril 2,5 mg/gün)', 'Doz 2–4 haftada bir titre edilir.', 12, 'now'),
      ('Hipertansiyon', 'Gebelikte hangi antihipertansifler tercih edilir?', 'Metildopa, labetalol, nifedipin', null, 14, 'now'),
      ('Hipertansiyon', 'Gebelikte hangi antihipertansif gruplar kontrendikedir?', 'ACE inhibitörleri ve ARB''ler', 'Fetüse zarar verirler.', 14, '2'),
      ('Hipertansiyon', 'Diyabetik hipertansif hastada ilk seçenek nedir?', 'ACE inhibitörü veya ARB', 'Böbreği korudukları için tercih edilir.', 15, '3'),
      ('Hipertansiyon', 'Hipertansif acil durumda ilk saatte tansiyon en fazla ne kadar düşürülür?', '%25', 'Damar yoluyla verilen ilaçlarla.', 16, '4'),
      ('Hipertansiyon', 'Hipertansif ivedi durumda tansiyon ne kadar sürede düşürülür?', '24–48 saatte, ağızdan ilaçlarla yavaşça', 'Çok hızlı düşürmek beyin ve kalbe zarar verebilir.', 16, '5'),
      ('Parasetamol toksisitesi', 'Parasetamol zehirlenmesinin antidotu nedir?', 'N-asetilsistein (NAC)', null, 9, 'now'),
      ('Parasetamol toksisitesi', 'Parasetamolün toksik metaboliti hangisidir?', 'NAPQI', 'CYP2E1 ile oluşur.', 6, 'now'),
      ('Parasetamol toksisitesi', 'NAPQI normalde neyle zararsız hale getirilir?', 'Glutatyon', 'Glutatyon tükenince karaciğer hasarı başlar.', 6, 'now'),
      ('Parasetamol toksisitesi', 'Parasetamol zehirlenmesinde hangi organ hasar görür?', 'Karaciğer (sentrilobüler nekroz)', null, 7, '1'),
      ('Parasetamol toksisitesi', 'Tedavi kararında hangi nomogram kullanılır?', 'Rumack–Matthew nomogramı', 'Alımdan en erken 4 saat sonra ölçülen plazma düzeyiyle.', 8, '2'),
      ('Parasetamol toksisitesi', 'N-asetilsistein en etkili ne zaman verilir?', 'Alımdan sonraki ilk 8 saat içinde', null, 9, '6')
    ) as v(lesson, q, a, note, page, due)
  loop
    select d.id into cid from public.card_decks d
      join public.materials ma on ma.id = d.material_id
     where d.user_id = uid and ma.title = m.lesson;
    if cid is null then
      insert into public.card_decks (user_id, course_id, material_id, lang, title)
      select uid, ma.course_id, ma.id, 'tr', ma.title from public.materials ma where ma.user_id = uid and ma.title = m.lesson
      returning id into cid;
    end if;
    insert into public.flashcards (deck_id, user_id, question, answer, note, page, sort_order, due_at, interval_days, reps, last_rating, last_reviewed_at)
    values (cid, uid, m.q, m.a, m.note, m.page,
            (select count(*) from public.flashcards f where f.deck_id = cid),
            case when m.due = 'now' then now() - interval '2 hours' else now() + make_interval(days => m.due::int) end,
            case when m.due = 'now' then 0 else 4 end,
            case when m.due = 'now' then 0 else 1 end,
            case when m.due = 'now' then null else 'good'::public.card_rating end,
            case when m.due = 'now' then null else now() - make_interval(days => greatest(1, 4 - m.due::int)) end);
    cid := null;
  end loop;

  -- ── Exam prep for Farmakoterapi (made by the server: Edge Functions generate-summary / generate-quiz) ──
  -- Topics of the Hipertansiyon lesson, the exam-prep summary (topics by importance) and questions in the lecturer's style.
  select id into mid from public.materials where user_id = uid and title = 'Hipertansiyon';
  select course_id into cid from public.materials where id = mid;
  insert into public.material_topics (material_id, user_id, title, page_from, page_to, importance, teacher_minutes, teacher_said_exam, sort_order)
  select mid, uid, v.* from (values
      ('Hipertansif kriz', 16, 16, 3, null, false, 0),
      ('ACE inhibitörleri yan etkileri', 12, 13, 3, null, false, 1),
      ('Tiyazid kontrendikasyonları', 14, 14, 2, 9, true, 2),
      ('Gebelikte hipertansiyon', 14, 14, 2, null, false, 3),
      ('İlk basamak ilaçlar', 12, 12, 1, null, false, 4)
  ) as v(title, page_from, page_to, importance, teacher_minutes, teacher_said_exam, sort_order);

  -- Weak topics come from earlier quiz answers (topic_progress.mastery).
  insert into public.topic_progress (user_id, topic_id, state, mastery)
  select uid, t.id, 'weak', v.mastery from (values ('Hipertansif kriz', 38), ('ACE inhibitörleri yan etkileri', 54)) as v(title, mastery)
  join public.material_topics t on t.material_id = mid and t.title = v.title;

  insert into public.summaries (user_id, course_id, material_id, lang, kind, content)
  values (uid, cid, mid, 'tr', 'exam_prep', '{"topics":[{"title":"Hipertansif kriz","kind":"weak","reason":{"type":"weak","mastery":38},"pageFrom":16,"pageTo":16,"points":["Kan basıncı 180/120 mmHg''nin üstündedir.","Organ hasarı varsa hipertansif acil durumdur; yoksa ivedi durumdur.","Acil durumda ilk saatte kan basıncı en fazla %25 düşürülür."]},{"title":"ACE inhibitörleri yan etkileri","kind":"weak","reason":{"type":"weak","mastery":54},"pageFrom":12,"pageTo":13,"points":["En sık yan etki kuru öksürüktür (bradikinin birikimi).","Nadiren anjiyoödem görülür; potasyumu yükseltebilir.","Öksürük olursa ARB''ye geçilir; ARB bradikinini artırmaz."],"molecule":"captopril"},{"title":"Tiyazid kontrendikasyonları","kind":"imp","reason":{"type":"teacher","minutes":9},"pageFrom":14,"pageTo":14,"points":["Tiyazidler serum ürik asit düzeyini artırır.","Gut, tiyazidler için zorunlu kontrendikasyondur.","Gebelik, metabolik sendrom ve glukoz intoleransı göreceli kontrendikasyonlardır."],"teacher":"Hoca derste bu konuda 9 dk durdu"},{"title":"Gebelikte hipertansiyon","kind":"imp","reason":{"type":"samples","count":4},"pageFrom":14,"pageTo":14,"points":["ACE inhibitörleri ve ARB''ler gebelikte kontrendikedir.","Metildopa ve labetalol tercih edilir; nifedipin de kullanılabilir."]},{"title":"İlk basamak ilaçlar","kind":"base","reason":{"type":"base"},"pageFrom":12,"pageTo":12,"points":["Dört grup: diüretikler, ACE inhibitörleri, ARB''ler ve kalsiyum kanal blokerleri.","ACE inhibitörlerine düşük dozla başlanır, doz 2–4 haftada bir artırılır."]}]}'::jsonb);

  insert into public.quizzes (user_id, course_id, material_id, kind, lang, teacher_style, options)
  values (uid, cid, mid, 'exam_prep', 'tr', true, '{"count": 6}')
  returning id into qid;
  insert into public.quiz_questions (quiz_id, user_id, topic_id, sort_order, kind, style_tag, text, options, answer_index, explanation, source_page, hints, molecule)
  select qid, uid, t.id, v.ord, 'multiple_choice', v.style, v.text, v.opts, v.ans, v.why, v.page, v.hints, v.mol
  from (values
      (0, 'case', '32 yaşında, 24 haftalık gebe hastada KB 160/105 mmHg. Aşağıdakilerden hangisi kullanılmamalıdır?', '["Metildopa","Labetalol","Nifedipin","Enalapril","Hidralazin"]'::jsonb, 3, 'ACE inhibitörleri (enalapril) gebelikte kontrendikedir; fetüste böbrek hasarı ve oligohidramniyoza yol açabilir. Metildopa ve labetalol güvenli seçeneklerdir.', 14, '["Gebelikte fetüsün böbreklerine zarar veren bir ilaç grubunu düşün. (s. 14)","Bu grup renin-anjiyotensin sistemini baskılar; gebelikte fetüs bu sisteme ihtiyaç duyar.","Şıklardan birinin adı \"-pril\" ile bitiyor."]'::jsonb, null, 'Gebelikte hipertansiyon'),
      (1, 'case', 'Gut öyküsü olan 60 yaşında hipertansif hastada hangi ilaç grubundan kaçınılmalıdır?', '["Tiyazid diüretikler","ACE inhibitörleri","ARB''ler","Kalsiyum kanal blokerleri","Beta blokerler"]'::jsonb, 0, 'Tiyazidler ürik asit düzeyini artırır ve gut atağını tetikleyebilir; gut zorunlu kontrendikasyondur. Hoca derste "sınavda soruyorum" dedi.', 14, '["Gut, kanda hangi maddenin yükselmesiyle ortaya çıkar? (s. 14)","Ürik asit atılımını azaltan bir ilaç grubu gut atağını tetikler.","Hocanın \"sınavda soruyorum\" dediği diüretik grubunu hatırla."]'::jsonb, null, 'Tiyazid kontrendikasyonları'),
      (2, 'side_effects', 'Ramipril başlanan hastada 3 hafta sonra kuru öksürük gelişti. En uygun yaklaşım hangisidir?', '["Dozu artırmak","Kodein eklemek","ARB''ye geçmek","Tiyazid eklemek","Tedaviyi aynen sürdürmek"]'::jsonb, 2, 'Öksürük bradikinin birikimine bağlıdır. ARB''ler bradikinin yıkımını etkilemez, bu yüzden öksürük yapmaz.', 12, '["Öksürüğe yol açan madde bradikinin; ACE onu da yıkar. (s. 13)","Aynı sistemi etkileyen ama bradikinini etkilemeyen bir grup var.","Bu grup reseptörü bloke eder: Anjiyotensin Reseptör Blokeri."]'::jsonb, null, 'ACE inhibitörleri yan etkileri'),
      (3, 'dose', 'Hipertansif acil durumda ilk saatte kan basıncı en fazla ne kadar düşürülmelidir?', '["%10","%25","%50","Hemen normale","%75"]'::jsonb, 1, 'Ani ve büyük düşüş organ perfüzyonunu bozar (inme, miyokard iskemisi). İlk saatte en fazla %25 düşürülür.', 16, '["Tansiyonu çok hızlı düşürmek beyne ve kalbe giden kanı azaltır. (s. 16)","Doğru cevap yarıdan az ama %10''dan fazla.","Bir çeyrek kadar düşün."]'::jsonb, null, 'Hipertansif kriz'),
      (4, 'knowledge', 'Aşağıdakilerden hangisi hipertansiyonda ilk basamak ilaç gruplarından biri değildir?', '["Tiyazid diüretikler","ACE inhibitörleri","ARB''ler","Kalsiyum kanal blokerleri","Alfa-1 blokerler"]'::jsonb, 4, 'Alfa-1 blokerler ilk basamak değildir; ilk dozdan sonra ortostatik hipotansiyon yapabilir. İlk basamak 4 grup: diüretik, ACE inh., ARB, KKB.', 12, '["İlk basamaktaki 4 grubu say: diüretik, ACE inhibitörü, ARB, … (s. 12)","Listede olmayanı bul: ilk dozdan sonra baş dönmesi ve bayılma yapabilen grup.","Ortostatik hipotansiyon yapan, \"ilk doz etkisi\" olan grup."]'::jsonb, null, 'İlk basamak ilaçlar'),
      (5, 'structure', 'Kaptopril yapısında işaretli grup (sarı) hangi yan etkiyle ilişkilidir?', '["Kuru öksürük","Tat bozukluğu ve döküntü","Hiperkalemi","Ortostatik hipotansiyon","Gut atağı"]'::jsonb, 1, 'İşaretli grup tiyol (–SH) grubudur. Kaptoprile özgü tat bozukluğu ve döküntü bu gruptan kaynaklanır. Kuru öksürük ise tüm ACE inhibitörlerinde bradikinin birikimine bağlıdır.', 12, '["İşaretli grup kükürt içerir: –SH (tiyol). (s. 13)","Kuru öksürük tüm ACE inhibitörlerinde görülür, yani bu gruba özgü değildir.","Bu yan etki ağızda hissedilir ve ciltte görülür."]'::jsonb, '{"name":"captopril"}'::jsonb, 'ACE inhibitörleri yan etkileri')
  ) as v(ord, style, text, opts, ans, why, page, hints, mol, topic)
  left join public.material_topics t on t.material_id = mid and t.title = v.topic;

  -- Section check started from the reader ("Başla"): two questions of the same lesson.
  insert into public.quizzes (user_id, course_id, material_id, kind, lang, teacher_style, options)
  values (uid, cid, mid, 'section_check', 'tr', true, '{"count": 2}')
  returning id into qid2;
  insert into public.quiz_questions (quiz_id, user_id, topic_id, sort_order, kind, style_tag, text, options, answer_index, explanation, source_page, hints, molecule)
  select qid2, uid, topic_id, sort_order - 1, kind, style_tag, text, options, answer_index, explanation, source_page, hints, molecule
  from public.quiz_questions where quiz_id = qid and sort_order in (1, 2);

  -- ── This week's study plan (made by the server: Edge Function build-plan / daily planner) ──
  -- Past days are done, except two missed tasks
  -- the day before today (for "I missed yesterday"). 6 study days, Sunday is the rest day.
  update public.user_settings set study_days = 6 where user_id = uid;
  insert into public.study_plans (user_id, week_start, stage, reasons)
  values (uid, date_trunc('week', current_date)::date, 'smart', jsonb_build_array(
    jsonb_build_object('text', 'Vize haftası ' || to_char(current_date + 4, 'DD') || '–' || to_char(current_date + 8, 'DD.MM') || ' · sınavı yakın derse daha çok süre', 'color', 'pri'),
    jsonb_build_object('text', 'Zayıf konuların: Hipertansif kriz %38, ACE inh. %54', 'color', 'pri'),
    jsonb_build_object('text', 'Hocanın derste uzun durduğu ve sorularında çok çıkan konular', 'color', 'amb'),
    jsonb_build_object('text', 'Öğrendiğin konular birkaç gün sonra kısa tekrar olarak geri gelir', 'color', 'good')))
  returning id into pid;

  insert into public.plan_items (plan_id, user_id, day, course_id, material_id, kind, title, minutes, why, target, status, sort_order, done_at)
  select pid, uid, d.day, co.id, ma.id, v.kind, v.title, v.minutes, v.why, v.target,
         case when d.day < current_date - 1 then 'done'::public.task_status
              when d.day = current_date - 1 and v.ord = 0 then 'done' else 'todo' end,
         v.ord,
         case when d.day < current_date - 1 or (d.day = current_date - 1 and v.ord = 0) then d.day + time '20:00' end
  from (values
    (0, 0, 'Farmakoterapi',            'Hipertansiyon',              'read',      'Hipertansif kriz',             35, 'zayıf konun · %38',          'reader'),
    (0, 1, 'Toksikoloji',              'Organofosfat zehirlenmesi',  'read',      'Organofosfat zehirlenmesi',    35, 'vizesi yakın',               'reader'),
    (0, 2, null,                       null,                         'review',    '3 gün önceki konular',         20, 'unutmaman için',             'cards'),
    (1, 0, 'Farmakoterapi',            'Hipertansiyon',              'read',      'ACE inh. yan etkileri',        40, 'zayıf konun · %54',          'reader'),
    (1, 1, 'Farmasötik Teknoloji III', 'Tablet formülasyonu',        'read',      'Tablet formülasyonu',          30, 'hoca 12 dk durdu',           'reader'),
    (2, 0, 'Toksikoloji',              'Parasetamol toksisitesi',    'read',      'Parasetamol toksisitesi',      45, 'sorularında 3 kez',          'reader'),
    (2, 1, 'Farmakoterapi',            'Hipertansiyon',              'read',      'Gebelikte hipertansiyon',      25, 'sorularında 4 kez',          'reader'),
    (2, 2, null,                       null,                         'cards',     'Kartlar',                      20, 'tekrar günü',                'cards'),
    (3, 0, 'Farmakoterapi',            'Hipertansiyon',              'read',      'Tiyazid kontrendikasyonları',  30, 'hoca: "sınavda soruyorum"',  'reader'),
    (3, 1, 'Toksikoloji',              'Ağır metaller',              'read',      'Ağır metaller',                40, 'zayıf konun · %49',          'reader'),
    (3, 2, null,                       null,                         'review',    'Haftanın tekrarı',             20, 'unutmaman için',             'cards'),
    (4, 0, 'Farmakoterapi',            'Hipertansiyon',              'review',    'Hipertansiyon tekrarı',        10, 'özet + 6 kart',              'cards'),
    (4, 1, 'Farmakoterapi',            'Diyabet',                    'read',      'Diyabet · Bölüm 2',            25, 'okuma',                      'reader'),
    (4, 2, 'Toksikoloji',              null,                         'quiz',      'Toksikoloji kısa sınav',       15, '10 soru',                    'quiz'),
    (5, 0, 'Farmakoterapi',            null,                         'exam_prep', 'Farmakoterapi özeti',          40, 'vizeden önce',               'exam_prep'),
    (5, 1, 'Farmakoterapi',            null,                         'exam_prep', 'Sınava özel 6 soru',           30, 'zayıf konulardan',           'quiz'),
    (5, 2, 'Farmakoterapi',            null,                         'mistakes',  'Yanlışlarını tekrar',          20, 'son sınavdan',               'quiz')
  ) as v(d, ord, course, lesson, kind, title, minutes, why, target)
  -- d is the weekday in the example (4 = today); days are placed around today so today always has tasks.
  cross join lateral (select (current_date + (v.d - 4)) as day) d
  left join public.courses co on co.user_id = uid and co.name = v.course
  left join public.materials ma on ma.user_id = uid and ma.title = v.lesson;

  -- Today's short review on home ("Bugün tekrar günü").
  insert into public.review_sessions (user_id, course_id, material_id, scheduled_for, minutes, content)
  select uid, ma.course_id, ma.id, current_date, 8,
         '{"summary": true, "cards": 6, "questions": 3, "reasons": ["weak", "forgetting"]}'::jsonb
  from public.materials ma where ma.user_id = uid and ma.title = 'Hipertansiyon';

  -- ── Graded quiz history (score and level are written by the server: Edge Function grade-quiz) ──
  -- One short review quiz per course, tried several times; morning tries score higher than late-night ones.
  for m in
    select * from (values
      ('Farmakoterapi',            30, '23:10', 52, 'improving'),
      ('Farmakoterapi',            20, '22:40', 58, 'improving'),
      ('Farmakoterapi',            12, '19:30', 61, 'improving'),
      ('Farmakoterapi',             6, '10:15', 64, 'improving'),
      ('Farmakoterapi',             1, '09:40', 70, 'very_good'),
      ('Toksikoloji',              20, '22:30', 64, 'improving'),
      ('Toksikoloji',               9, '19:00', 74, 'very_good'),
      ('Toksikoloji',               2, '10:20', 85, 'expert'),
      ('Farmasötik Teknoloji III', 28, '09:20', 84, 'very_good'),
      ('Farmasötik Teknoloji III', 21, '10:05', 88, 'expert'),
      ('Farmasötik Teknoloji III', 14, '09:50', 92, 'expert'),
      ('Farmasötik Teknoloji III',  3, '09:30', 96, 'expert')
    ) as v(course, days_ago, at, score, lvl)
  loop
    select q.id into qid from public.quizzes q join public.courses co on co.id = q.course_id
     where q.user_id = uid and q.kind = 'review' and co.name = m.course;
    if qid is null then
      insert into public.quizzes (user_id, course_id, kind, lang, teacher_style, options)
      select uid, co.id, 'review', 'tr', true, '{"count": 10}' from public.courses co where co.user_id = uid and co.name = m.course
      returning id into qid;
    end if;
    insert into public.quiz_attempts (quiz_id, user_id, started_at, finished_at, score, level)
    values (qid, uid,
            ((current_date - m.days_ago) + m.at::time) at time zone 'Europe/Istanbul',
            ((current_date - m.days_ago) + m.at::time + interval '12 minutes') at time zone 'Europe/Istanbul',
            m.score, m.lvl);
    qid := null;
  end loop;

  -- More weak topics (from those quizzes): one in Diyabet, one in Ağır metaller.
  insert into public.material_topics (material_id, user_id, title, page_from, page_to, importance, sort_order)
  select ma.id, uid, v.title, v.p1, v.p2, 3, 0
  from (values ('Diyabet', 'İnsülin türleri', 8, 11), ('Ağır metaller', 'Kurşun zehirlenmesi', 5, 9)) as v(lesson, title, p1, p2)
  join public.materials ma on ma.user_id = uid and ma.title = v.lesson;
  insert into public.topic_progress (user_id, topic_id, state, mastery)
  select uid, t.id, 'weak', v.mastery
  from (values ('İnsülin türleri', 61), ('Kurşun zehirlenmesi', 49)) as v(title, mastery)
  join public.material_topics t on t.user_id = uid and t.title = v.title;

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
