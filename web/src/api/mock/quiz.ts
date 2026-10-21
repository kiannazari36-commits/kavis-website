// Exam-prep mock data from design/NewIPad.dc.html ("Sınava özel"): summary topics and questions in the lecturer's style.
import type { ExamTopic, QuizQuestion } from '../types';

export const EXAM_TOPICS: ExamTopic[] = [
  {
    "title": {
      "tr": "Hipertansif kriz",
      "en": "Hypertensive crisis",
      "fa": "بحران فشار خون بالا",
      "ar": "أزمة ارتفاع ضغط الدم"
    },
    "tag": {
      "tr": "zayıf konun · %38",
      "en": "weak topic · 38%",
      "fa": "مبحث ضعیف · %38",
      "ar": "موضوع ضعيف · 38%"
    },
    "kind": "weak",
    "src": {
      "tr": "S. 21–22",
      "en": "pp. 21–22",
      "fa": "ص. 21–22",
      "ar": "ص. 21–22"
    },
    "points": [
      {
        "tr": "Kan basıncı 180/120 mmHg'nin üstündedir.",
        "en": "BP is above 180/120 mmHg.",
        "fa": "فشار خون بالای 180/120 mmHg است.",
        "ar": "ضغط الدم فوق 180/120 mmHg."
      },
      {
        "tr": "Organ hasarı varsa hipertansif acil durumdur; yoksa ivedi durumdur.",
        "en": "With organ damage it's a hypertensive emergency; without, it's a hypertensive urgency.",
        "fa": "اگر آسیب ارگان باشد اورژانس فشار خون است؛ وگرنه فوریت فشار خون است.",
        "ar": "إذا وُجد تلف عضوي فهي طوارئ ارتفاع ضغط الدم؛ وإلا فهي حالة إلحاحية."
      },
      {
        "tr": "Acil durumda ilk saatte kan basıncı en fazla %25 düşürülür.",
        "en": "In an emergency, blood pressure is lowered by at most 25% in the first hour.",
        "fa": "در اورژانس، فشار خون در ساعت اول حداکثر 25% کاهش داده می‌شود.",
        "ar": "في الطوارئ يُخفض ضغط الدم بنسبة 25% كحد أقصى في الساعة الأولى."
      }
    ]
  },
  {
    "title": {
      "tr": "ACE inhibitörleri yan etkileri",
      "en": "ACE inhibitor side effects",
      "fa": "عوارض جانبی مهارکننده‌های ACE",
      "ar": "الآثار الجانبية لمثبطات ACE"
    },
    "tag": {
      "tr": "zayıf konun · %54",
      "en": "weak topic · 54%",
      "fa": "مبحث ضعیف · %54",
      "ar": "موضوع ضعيف · 54%"
    },
    "kind": "weak",
    "src": {
      "tr": "S. 12–13",
      "en": "pp. 12–13",
      "fa": "ص. 12–13",
      "ar": "ص. 12–13"
    },
    "points": [
      {
        "tr": "En sık yan etki kuru öksürüktür (bradikinin birikimi).",
        "en": "The most common side effect is dry cough (bradykinin buildup).",
        "fa": "شایع‌ترین عارضه جانبی سرفه خشک است (تجمع برادی‌کینین).",
        "ar": "أكثر الآثار الجانبية شيوعًا هو السعال الجاف (تراكم البراديكينين)."
      },
      {
        "tr": "Nadiren anjiyoödem görülür; potasyumu yükseltebilir.",
        "en": "Angioedema is rare; it can raise potassium.",
        "fa": "به‌ندرت آنژیوادم دیده می‌شود؛ می‌تواند پتاسیم را بالا ببرد.",
        "ar": "نادرًا ما تحدث الوذمة الوعائية؛ وقد يرفع البوتاسيوم."
      },
      {
        "tr": "Öksürük olursa ARB'ye geçilir; ARB bradikinini artırmaz.",
        "en": "If cough occurs, switch to an ARB; ARBs don't raise bradykinin.",
        "fa": "اگر سرفه ایجاد شود، به ARB تغییر می‌دهند؛ ARB برادی‌کینین را افزایش نمی‌دهد.",
        "ar": "إذا حدث السعال يُنتقل إلى ARB؛ فهو لا يرفع البراديكينين."
      }
    ],
    "molecule": "captopril"
  },
  {
    "title": {
      "tr": "Tiyazid kontrendikasyonları",
      "en": "Thiazide contraindications",
      "fa": "منع مصرف تیازیدها",
      "ar": "مضادات استطباب الثيازيدات"
    },
    "tag": {
      "tr": "hoca 9 dk durdu · \"sınavda soruyorum\"",
      "en": "lecturer spent 9 min · \"I ask this in the exam\"",
      "fa": "استاد 9 دقیقه رویش ماند · \"در امتحان می‌پرسم\"",
      "ar": "توقف المحاضر 9 د · \"أسأل عنه في الامتحان\""
    },
    "kind": "imp",
    "src": {
      "tr": "S. 14",
      "en": "p. 14",
      "fa": "ص. 14",
      "ar": "ص. 14"
    },
    "points": [
      {
        "tr": "Tiyazidler serum ürik asit düzeyini artırır.",
        "en": "Thiazides raise serum uric acid.",
        "fa": "تیازیدها اسید اوریک سرم را بالا می‌برند.",
        "ar": "ترفع الثيازيدات حمض اليوريك في المصل."
      },
      {
        "tr": "Gut, tiyazidler için zorunlu kontrendikasyondur.",
        "en": "Gout is an absolute contraindication for thiazides.",
        "fa": "نقرس منع مصرف مطلق برای تیازیدهاست.",
        "ar": "النقرس مانع استعمال مطلق للثيازيدات."
      },
      {
        "tr": "Gebelik, metabolik sendrom ve glukoz intoleransı göreceli kontrendikasyonlardır.",
        "en": "Pregnancy, metabolic syndrome and glucose intolerance are relative contraindications.",
        "fa": "بارداری، سندرم متابولیک و عدم تحمل گلوکز منع مصرف نسبی هستند.",
        "ar": "الحمل والمتلازمة الاستقلابية وعدم تحمل الغلوكوز موانع استعمال نسبية."
      }
    ],
    "teacher": {
      "tr": "Hoca derste bu konuda 9 dk durdu",
      "en": "Lecturer spent 9 min on this in class",
      "fa": "استاد سر کلاس 9 دقیقه روی این مبحث ماند",
      "ar": "توقف الأستاذ 9 د عند هذا في الدرس"
    }
  },
  {
    "title": {
      "tr": "Gebelikte hipertansiyon",
      "en": "Hypertension in pregnancy",
      "fa": "فشار خون بالا در بارداری",
      "ar": "ارتفاع ضغط الدم في الحمل"
    },
    "tag": {
      "tr": "sorularında 4 kez çıktı",
      "en": "came up 4× in their questions",
      "fa": "4 بار در سؤال‌هایش آمد",
      "ar": "ورد 4 مرات في أسئلته"
    },
    "kind": "imp",
    "src": {
      "tr": "S. 14",
      "en": "p. 14",
      "fa": "ص. 14",
      "ar": "ص. 14"
    },
    "points": [
      {
        "tr": "ACE inhibitörleri ve ARB'ler gebelikte kontrendikedir.",
        "en": "ACE inhibitors and ARBs are contraindicated in pregnancy.",
        "fa": "مهارکننده‌های ACE و ARBها در بارداری منع مصرف دارند.",
        "ar": "مثبطات ACE وARBs ممنوعة أثناء الحمل."
      },
      {
        "tr": "Metildopa ve labetalol tercih edilir; nifedipin de kullanılabilir.",
        "en": "Methyldopa and labetalol are preferred; nifedipine can also be used.",
        "fa": "متیل‌دوپا و لابتالول ترجیح داده می‌شوند؛ نیفدیپین هم قابل استفاده است.",
        "ar": "يُفضَّل ميثيل دوبا ولابيتالول؛ ويمكن استخدام النيفيديبين أيضًا."
      }
    ]
  },
  {
    "title": {
      "tr": "İlk basamak ilaçlar",
      "en": "First-line drugs",
      "fa": "داروهای خط اول",
      "ar": "أدوية الخط الأول"
    },
    "tag": {
      "tr": "temel konu · özet",
      "en": "core topic · summary",
      "fa": "مبحث پایه · خلاصه",
      "ar": "موضوع أساسي · ملخص"
    },
    "kind": "base",
    "src": {
      "tr": "S. 12",
      "en": "p. 12",
      "fa": "ص. 12",
      "ar": "ص. 12"
    },
    "points": [
      {
        "tr": "Dört grup: diüretikler, ACE inhibitörleri, ARB'ler ve kalsiyum kanal blokerleri.",
        "en": "Four groups: diuretics, ACE inhibitors, ARBs and calcium channel blockers.",
        "fa": "چهار گروه: دیورتیک‌ها، مهارکننده‌های ACE، ARBها و مسدودکننده‌های کانال کلسیم.",
        "ar": "أربع مجموعات: مدرات البول ومثبطات ACE وARBs وحاصرات قنوات الكالسيوم."
      },
      {
        "tr": "ACE inhibitörlerine düşük dozla başlanır, doz 2–4 haftada bir artırılır.",
        "en": "ACE inhibitors are started at a low dose, increased every 2–4 weeks.",
        "fa": "مهارکننده‌های ACE با دوز پایین شروع و هر 2–4 هفته افزایش می‌یابند.",
        "ar": "تُبدأ مثبطات ACE بجرعة منخفضة وتُزاد كل 2–4 أسابيع."
      }
    ]
  }
];

export const QUIZ_QUESTIONS: QuizQuestion[] = [
  {
    "kind": {
      "tr": "Hasta vakası",
      "en": "Patient case",
      "fa": "مورد بیمار",
      "ar": "حالة مريض"
    },
    "text": {
      "tr": "32 yaşında, 24 haftalık gebe hastada KB 160/105 mmHg. Aşağıdakilerden hangisi kullanılmamalıdır?",
      "en": "A 32-year-old patient, 24 weeks pregnant, has BP 160/105 mmHg. Which of the following should not be used?",
      "fa": "بیمار 32 ساله، باردار 24 هفته، فشار خون 160/105 mmHg. کدام یک از موارد زیر نباید استفاده شود؟",
      "ar": "مريضة عمرها 32 عامًا، حامل في الأسبوع 24، ضغطها 160/105 mmHg. أيٌّ مما يلي يجب ألا يُستخدم؟"
    },
    "options": [
      {
        "tr": "Metildopa",
        "en": "Methyldopa",
        "fa": "متیل‌دوپا",
        "ar": "ميثيل دوبا"
      },
      {
        "tr": "Labetalol",
        "en": "Labetalol",
        "fa": "لابتالول",
        "ar": "لابيتالول"
      },
      {
        "tr": "Nifedipin",
        "en": "Nifedipine",
        "fa": "نیفدیپین",
        "ar": "نيفيديبين"
      },
      {
        "tr": "Enalapril",
        "en": "Enalapril",
        "fa": "انالاپریل",
        "ar": "إينالابريل"
      },
      {
        "tr": "Hidralazin",
        "en": "Hydralazine",
        "fa": "هیدرالازین",
        "ar": "هيدرالازين"
      }
    ],
    "answer": 3,
    "why": {
      "tr": "ACE inhibitörleri (enalapril) gebelikte kontrendikedir; fetüste böbrek hasarı ve oligohidramniyoza yol açabilir. Metildopa ve labetalol güvenli seçeneklerdir.",
      "en": "ACE inhibitors (enalapril) are contraindicated in pregnancy; they can cause fetal kidney damage and oligohydramnios. Methyldopa and labetalol are safe options.",
      "fa": "مهارکننده‌های ACE (انالاپریل) در بارداری منع مصرف دارند؛ می‌توانند باعث آسیب کلیهٔ جنین و الیگوهیدرآمنیوس شوند. متیل‌دوپا و لابتالول گزینه‌های ایمن‌اند.",
      "ar": "مثبطات ACE (إنالابريل) ممنوعة أثناء الحمل؛ قد تسبب تلفًا كلويًا للجنين وقلة السائل الأمنيوسي. ميثيل دوبا ولابيتالول خياران آمنان."
    },
    "src": {
      "tr": "S. 14 · Gebelikte hipertansiyon",
      "en": "p. 14 · Hypertension in pregnancy",
      "fa": "ص. 14 · فشار خون بالا در بارداری",
      "ar": "ص. 14 · ارتفاع ضغط الدم في الحمل"
    },
    "hints": [
      {
        "tr": "Gebelikte fetüsün böbreklerine zarar veren bir ilaç grubunu düşün. (s. 14)",
        "en": "Think of a drug group that harms the fetus's kidneys in pregnancy. (p. 14)",
        "fa": "به گروه دارویی فکر کن که در بارداری به کلیه‌های جنین آسیب می‌زند. (ص. 14)",
        "ar": "فكّر في مجموعة دوائية تضر بكليتي الجنين أثناء الحمل. (ص. 14)"
      },
      {
        "tr": "Bu grup renin-anjiyotensin sistemini baskılar; gebelikte fetüs bu sisteme ihtiyaç duyar.",
        "en": "This group suppresses the renin-angiotensin system; in pregnancy the fetus needs this system.",
        "fa": "این گروه سیستم رنین-آنژیوتانسین را مهار می‌کند؛ در بارداری جنین به این سیستم نیاز دارد.",
        "ar": "هذه المجموعة تثبط نظام الرينين-أنجيوتنسين؛ والجنين يحتاج هذا النظام أثناء الحمل."
      },
      {
        "tr": "Şıklardan birinin adı \"-pril\" ile bitiyor.",
        "en": "One option's name ends in \"-pril\".",
        "fa": "نام یکی از گزینه‌ها با «-pril» تمام می‌شود.",
        "ar": "اسم أحد الخيارات ينتهي بـ \"-pril\"."
      }
    ]
  },
  {
    "kind": {
      "tr": "Hasta vakası",
      "en": "Patient case",
      "fa": "مورد بیمار",
      "ar": "حالة مريض"
    },
    "text": {
      "tr": "Gut öyküsü olan 60 yaşında hipertansif hastada hangi ilaç grubundan kaçınılmalıdır?",
      "en": "In a 60-year-old hypertensive patient with a history of gout, which drug group should be avoided?",
      "fa": "در بیمار 60 ساله مبتلا به فشار خون بالا با سابقه نقرس، از کدام گروه دارویی باید پرهیز کرد؟",
      "ar": "لدى مريض بارتفاع ضغط الدم عمره 60 عامًا وله سوابق نقرس، أي مجموعة دوائية يجب تجنبها؟"
    },
    "options": [
      {
        "tr": "Tiyazid diüretikler",
        "en": "Thiazide diuretics",
        "fa": "دیورتیک‌های تیازیدی",
        "ar": "مدرات البول الثيازيدية"
      },
      {
        "tr": "ACE inhibitörleri",
        "en": "ACE inhibitors",
        "fa": "مهارکننده‌های ACE",
        "ar": "مثبطات ACE"
      },
      {
        "tr": "ARB'ler",
        "en": "ARBs",
        "fa": "ARBها",
        "ar": "ARBs"
      },
      {
        "tr": "Kalsiyum kanal blokerleri",
        "en": "Calcium channel blockers",
        "fa": "مسدودکننده‌های کانال کلسیم",
        "ar": "حاصرات قنوات الكالسيوم"
      },
      {
        "tr": "Beta blokerler",
        "en": "Beta blockers",
        "fa": "بتابلاکرها",
        "ar": "حاصرات بيتا"
      }
    ],
    "answer": 0,
    "why": {
      "tr": "Tiyazidler ürik asit düzeyini artırır ve gut atağını tetikleyebilir; gut zorunlu kontrendikasyondur. Hoca derste \"sınavda soruyorum\" dedi.",
      "en": "Thiazides raise uric acid and can trigger a gout attack; gout is a compelling contraindication. The lecturer said \"I ask this in exams\".",
      "fa": "تیازیدها سطح اسید اوریک را بالا می‌برند و می‌توانند حمله نقرس را تحریک کنند؛ نقرس منع مصرف قطعی است. استاد سر کلاس گفت «این را در امتحان می‌پرسم».",
      "ar": "ترفع الثيازيدات مستوى حمض اليوريك وقد تثير نوبة نقرس؛ النقرس مضاد استطباب مطلق. قال المحاضر «أسأل هذا في الامتحان»."
    },
    "src": {
      "tr": "S. 14 · Tiyazid kontrendikasyonları",
      "en": "p. 14 · Thiazide contraindications",
      "fa": "ص. 14 · موارد منع مصرف تیازیدها",
      "ar": "ص. 14 · موانع استعمال الثيازيدات"
    },
    "hints": [
      {
        "tr": "Gut, kanda hangi maddenin yükselmesiyle ortaya çıkar? (s. 14)",
        "en": "Gout occurs due to a rise in which substance in the blood? (p. 14)",
        "fa": "نقرس با افزایش کدام ماده در خون بروز می‌کند؟ (ص. 14)",
        "ar": "يظهر النقرس بسبب ارتفاع أي مادة في الدم؟ (ص. 14)"
      },
      {
        "tr": "Ürik asit atılımını azaltan bir ilaç grubu gut atağını tetikler.",
        "en": "A drug group that reduces uric acid excretion triggers gout attacks.",
        "fa": "یک گروه دارویی که دفع اسید اوریک را کم می‌کند، حمله نقرس را تحریک می‌کند.",
        "ar": "مجموعة دوائية تقلل إطراح حمض اليوريك تُحفّز نوبة النقرس."
      },
      {
        "tr": "Hocanın \"sınavda soruyorum\" dediği diüretik grubunu hatırla.",
        "en": "Remember the diuretic group your lecturer said \"I'll ask in the exam\".",
        "fa": "گروه دیورتیکی را که استادت گفت «در امتحان می‌پرسم» به یاد بیاور.",
        "ar": "تذكّر مجموعة مدرات البول التي قال أستاذك عنها \"سأسأل عنها في الامتحان\"."
      }
    ]
  },
  {
    "kind": {
      "tr": "Yan etki",
      "en": "Side effect",
      "fa": "عارضه جانبی",
      "ar": "أثر جانبي"
    },
    "text": {
      "tr": "Ramipril başlanan hastada 3 hafta sonra kuru öksürük gelişti. En uygun yaklaşım hangisidir?",
      "en": "A patient started on ramipril developed a dry cough after 3 weeks. What is the best approach?",
      "fa": "بیماری که رامی‌پریل شروع کرده، بعد از 3 هفته سرفه خشک گرفته. مناسب‌ترین اقدام کدام است؟",
      "ar": "مريض بدأ الراميبريل وأصيب بسعال جاف بعد 3 أسابيع. ما هو النهج الأنسب؟"
    },
    "options": [
      {
        "tr": "Dozu artırmak",
        "en": "Increasing the dose",
        "fa": "افزایش دوز",
        "ar": "زيادة الجرعة"
      },
      {
        "tr": "Kodein eklemek",
        "en": "Adding codeine",
        "fa": "افزودن کدئین",
        "ar": "إضافة الكودايين"
      },
      {
        "tr": "ARB'ye geçmek",
        "en": "Switching to an ARB",
        "fa": "تغییر به ARB",
        "ar": "الانتقال إلى ARB"
      },
      {
        "tr": "Tiyazid eklemek",
        "en": "Add a thiazide",
        "fa": "افزودن تیازید",
        "ar": "إضافة ثيازيد"
      },
      {
        "tr": "Tedaviyi aynen sürdürmek",
        "en": "Continue treatment unchanged",
        "fa": "ادامه درمان بدون تغییر",
        "ar": "الاستمرار في العلاج دون تغيير"
      }
    ],
    "answer": 2,
    "why": {
      "tr": "Öksürük bradikinin birikimine bağlıdır. ARB'ler bradikinin yıkımını etkilemez, bu yüzden öksürük yapmaz.",
      "en": "The cough is due to bradykinin buildup. ARBs don't affect bradykinin breakdown, so they don't cause cough.",
      "fa": "سرفه به دلیل تجمع برادی‌کینین است. ARBها بر تجزیه برادی‌کینین اثری ندارند، پس سرفه ایجاد نمی‌کنند.",
      "ar": "يعود السعال إلى تراكم البراديكينين. لا تؤثر حاصرات مستقبلات الأنجيوتنسين (ARB) على تكسير البراديكينين، لذا لا تسبب السعال."
    },
    "src": {
      "tr": "S. 13 · ACE inhibitörleri yan etkileri",
      "en": "p. 13 · ACE inhibitor side effects",
      "fa": "ص. 13 · عوارض مهارکننده‌های ACE",
      "ar": "ص. 13 · الآثار الجانبية لمثبطات ACE"
    },
    "hints": [
      {
        "tr": "Öksürüğe yol açan madde bradikinin; ACE onu da yıkar. (s. 13)",
        "en": "The substance causing cough is bradykinin; ACE breaks it down too. (p. 13)",
        "fa": "ماده‌ای که سرفه ایجاد می‌کند برادی‌کینین است؛ ACE آن را هم تجزیه می‌کند. (ص. 13)",
        "ar": "المادة المسببة للسعال هي البراديكينين؛ والإنزيم ACE يكسرها أيضًا. (ص. 13)"
      },
      {
        "tr": "Aynı sistemi etkileyen ama bradikinini etkilemeyen bir grup var.",
        "en": "There's a group that acts on the same system but doesn't affect bradykinin.",
        "fa": "گروهی هست که روی همان سیستم اثر می‌کند ولی بر برادی‌کینین اثری ندارد.",
        "ar": "هناك مجموعة تؤثر في النظام نفسه لكنها لا تؤثر في البراديكينين."
      },
      {
        "tr": "Bu grup reseptörü bloke eder: Anjiyotensin Reseptör Blokeri.",
        "en": "This group blocks the receptor: Angiotensin Receptor Blocker.",
        "fa": "این گروه گیرنده را مسدود می‌کند: مسدودکننده‌ی گیرنده‌ی آنژیوتانسین.",
        "ar": "هذه المجموعة تحصر المستقبل: حاصرات مستقبلات الأنجيوتنسين."
      }
    ]
  },
  {
    "kind": {
      "tr": "Mekanizma / doz",
      "en": "Mechanism / dose",
      "fa": "مکانیسم / دوز",
      "ar": "الآلية / الجرعة"
    },
    "text": {
      "tr": "Hipertansif acil durumda ilk saatte kan basıncı en fazla ne kadar düşürülmelidir?",
      "en": "In a hypertensive emergency, by how much at most should BP be lowered in the first hour?",
      "fa": "در اورژانس فشار خون بالا، فشار خون در ساعت اول حداکثر چقدر باید پایین بیاید؟",
      "ar": "في طوارئ ارتفاع ضغط الدم، بكم يجب خفض الضغط كحد أقصى في الساعة الأولى؟"
    },
    "options": [
      {
        "tr": "%10",
        "en": "10%",
        "fa": "٪۱۰",
        "ar": "10%"
      },
      {
        "tr": "%25",
        "en": "25%",
        "fa": "٪۲۵",
        "ar": "25%"
      },
      {
        "tr": "%50",
        "en": "50%",
        "fa": "٪۵۰",
        "ar": "50%"
      },
      {
        "tr": "Hemen normale",
        "en": "Straight to normal",
        "fa": "فوراً به حالت عادی",
        "ar": "فورًا إلى الطبيعي"
      },
      {
        "tr": "%75",
        "en": "75%",
        "fa": "٪۷۵",
        "ar": "75%"
      }
    ],
    "answer": 1,
    "why": {
      "tr": "Ani ve büyük düşüş organ perfüzyonunu bozar (inme, miyokard iskemisi). İlk saatte en fazla %25 düşürülür.",
      "en": "A sudden large drop impairs organ perfusion (stroke, myocardial ischemia). At most 25% reduction in the first hour.",
      "fa": "افت ناگهانی و زیاد خون‌رسانی اعضا را مختل می‌کند (سکته، ایسکمی میوکارد). در ساعت اول حداکثر 25% کاهش داده می‌شود.",
      "ar": "الانخفاض المفاجئ الكبير يضعف تروية الأعضاء (سكتة، إقفار عضلة القلب). يُخفض بنسبة 25% كحد أقصى في الساعة الأولى."
    },
    "src": {
      "tr": "S. 21 · Hipertansif kriz",
      "en": "p. 21 · Hypertensive crisis",
      "fa": "ص. 21 · بحران فشار خون",
      "ar": "ص. 21 · أزمة ارتفاع ضغط الدم"
    },
    "hints": [
      {
        "tr": "Tansiyonu çok hızlı düşürmek beyne ve kalbe giden kanı azaltır. (s. 21)",
        "en": "Lowering blood pressure too fast reduces blood flow to the brain and heart. (p. 21)",
        "fa": "کاهش خیلی سریع فشار خون، خون‌رسانی به مغز و قلب را کم می‌کند. (ص. 21)",
        "ar": "خفض ضغط الدم بسرعة كبيرة يقلل تدفق الدم إلى الدماغ والقلب. (ص. 21)"
      },
      {
        "tr": "Doğru cevap yarıdan az ama %10'dan fazla.",
        "en": "Fewer than half correct, but more than 10%.",
        "fa": "پاسخ درست کمتر از نصف اما بیشتر از %10 است.",
        "ar": "الإجابات الصحيحة أقل من النصف لكن أكثر من 10%."
      },
      {
        "tr": "Bir çeyrek kadar düşün.",
        "en": "Think about it for a quarter hour.",
        "fa": "حدود یک ربع فکر کن.",
        "ar": "فكّر فيها ربع ساعة تقريباً."
      }
    ]
  },
  {
    "kind": {
      "tr": "Bilgi",
      "en": "Info",
      "fa": "اطلاعات",
      "ar": "معلومات"
    },
    "text": {
      "tr": "Aşağıdakilerden hangisi hipertansiyonda ilk basamak ilaç gruplarından biri değildir?",
      "en": "Which of the following is NOT a first-line drug group in hypertension?",
      "fa": "کدام‌یک از موارد زیر جزو گروه‌های دارویی خط اول در فشار خون بالا نیست؟",
      "ar": "أيٌّ مما يلي ليس من مجموعات الأدوية الخط الأول في ارتفاع ضغط الدم؟"
    },
    "options": [
      {
        "tr": "Tiyazid diüretikler",
        "en": "Thiazide diuretics",
        "fa": "دیورتیک‌های تیازیدی",
        "ar": "مدرات البول الثيازيدية"
      },
      {
        "tr": "ACE inhibitörleri",
        "en": "ACE inhibitors",
        "fa": "مهارکننده‌های ACE",
        "ar": "مثبطات ACE"
      },
      {
        "tr": "ARB'ler",
        "en": "ARBs",
        "fa": "ARBها",
        "ar": "ARBs"
      },
      {
        "tr": "Kalsiyum kanal blokerleri",
        "en": "Calcium channel blockers",
        "fa": "مسدودکننده‌های کانال کلسیم",
        "ar": "حاصرات قنوات الكالسيوم"
      },
      {
        "tr": "Alfa-1 blokerler",
        "en": "Alpha-1 blockers",
        "fa": "مسدودکننده‌های آلفا-1",
        "ar": "حاصرات ألفا-1"
      }
    ],
    "answer": 4,
    "why": {
      "tr": "Alfa-1 blokerler ilk basamak değildir; ilk dozdan sonra ortostatik hipotansiyon yapabilir. İlk basamak 4 grup: diüretik, ACE inh., ARB, KKB.",
      "en": "Alpha-1 blockers aren't first-line; they can cause orthostatic hypotension after the first dose. First line is 4 groups: diuretic, ACE inh., ARB, CCB.",
      "fa": "مسدودکننده‌های آلفا-1 خط اول نیستند؛ بعد از دوز اول ممکن است افت فشار وضعیتی ایجاد کنند. خط اول 4 گروه است: دیورتیک، مهارکنندهٔ ACE، ARB، CCB.",
      "ar": "حاصرات ألفا-1 ليست خط العلاج الأول؛ قد تسبب هبوط الضغط الانتصابي بعد الجرعة الأولى. الخط الأول 4 مجموعات: مدر، مثبط ACE، ARB، CCB."
    },
    "src": {
      "tr": "S. 12–13 · İlk basamak ilaçlar",
      "en": "pp. 12–13 · First-line drugs",
      "fa": "ص. 12–13 · داروهای خط اول",
      "ar": "ص. 12–13 · أدوية الخط الأول"
    },
    "hints": [
      {
        "tr": "İlk basamaktaki 4 grubu say: diüretik, ACE inhibitörü, ARB, … (s. 12)",
        "en": "Name the 4 first-line groups: diuretic, ACE inhibitor, ARB, … (p. 12)",
        "fa": "4 گروه خط اول را نام ببر: دیورتیک، مهارکننده ACE، ARB، … (ص. 12)",
        "ar": "عدّد مجموعات الخط الأول الأربع: مدر بول، مثبط ACE، ARB، … (ص. 12)"
      },
      {
        "tr": "Listede olmayanı bul: ilk dozdan sonra baş dönmesi ve bayılma yapabilen grup.",
        "en": "Find the one not on the list: the group that can cause dizziness and fainting after the first dose.",
        "fa": "آن را که در فهرست نیست پیدا کن: گروهی که بعد از اولین دوز می‌تواند سرگیجه و غش ایجاد کند.",
        "ar": "اعثر على غير المذكور في القائمة: المجموعة التي قد تسبب دوخة وإغماء بعد الجرعة الأولى."
      },
      {
        "tr": "Ortostatik hipotansiyon yapan, \"ilk doz etkisi\" olan grup.",
        "en": "The group that causes orthostatic hypotension, with a \"first-dose effect\".",
        "fa": "گروهی که افت فشار وضعیتی ایجاد می‌کند و «اثر دوز اول» دارد.",
        "ar": "المجموعة التي تسبب هبوط الضغط الانتصابي ولها \"تأثير الجرعة الأولى\"."
      }
    ]
  },
  {
    "kind": {
      "tr": "Yapı / yan etki",
      "en": "Structure / side effect",
      "fa": "ساختار / عارضه جانبی",
      "ar": "البنية / الأثر الجانبي"
    },
    "text": {
      "tr": "Kaptopril yapısında işaretli grup (sarı) hangi yan etkiyle ilişkilidir?",
      "en": "In captopril's structure, which side effect is the marked group (yellow) linked to?",
      "fa": "در ساختار کاپتوپریل، گروه علامت‌خورده (زرد) با کدام عارضه جانبی مرتبط است؟",
      "ar": "في بنية الكابتوبريل، بأي أثر جانبي ترتبط المجموعة المعلّمة (الأصفر)؟"
    },
    "options": [
      {
        "tr": "Kuru öksürük",
        "en": "Dry cough",
        "fa": "سرفهٔ خشک",
        "ar": "سعال جاف"
      },
      {
        "tr": "Tat bozukluğu ve döküntü",
        "en": "Taste disturbance and rash",
        "fa": "اختلال چشایی و بثورات پوستی",
        "ar": "اضطراب التذوق والطفح الجلدي"
      },
      {
        "tr": "Hiperkalemi",
        "en": "Hyperkalemia",
        "fa": "هیپرکالمی",
        "ar": "فرط بوتاسيوم الدم"
      },
      {
        "tr": "Ortostatik hipotansiyon",
        "en": "Orthostatic hypotension",
        "fa": "افت فشار خون وضعیتی",
        "ar": "هبوط الضغط الانتصابي"
      },
      {
        "tr": "Gut atağı",
        "en": "Gout attack",
        "fa": "حمله نقرس",
        "ar": "نوبة النقرس"
      }
    ],
    "answer": 1,
    "why": {
      "tr": "İşaretli grup tiyol (–SH) grubudur. Kaptoprile özgü tat bozukluğu ve döküntü bu gruptan kaynaklanır. Kuru öksürük ise tüm ACE inhibitörlerinde bradikinin birikimine bağlıdır.",
      "en": "The marked group is the thiol (–SH) group. Captopril's typical taste disturbance and rash come from this group. Dry cough, however, is due to bradykinin buildup in all ACE inhibitors.",
      "fa": "گروه علامت‌خورده گروه تیول (–SH) است. اختلال چشایی و بثورات مخصوص کاپتوپریل از این گروه است. اما سرفه خشک در همه مهارکننده‌های ACE به دلیل تجمع برادی‌کینین است.",
      "ar": "المجموعة المحددة هي مجموعة الثيول (–SH). اضطراب التذوق والطفح الخاصان بالكابتوبريل ناتجان عنها. أما السعال الجاف فيعود إلى تراكم البراديكينين في جميع مثبطات ACE."
    },
    "src": {
      "tr": "S. 13 · ACE inhibitörleri yan etkileri",
      "en": "p. 13 · ACE inhibitor side effects",
      "fa": "ص. 13 · عوارض مهارکننده‌های ACE",
      "ar": "ص. 13 · الآثار الجانبية لمثبطات ACE"
    },
    "hints": [
      {
        "tr": "İşaretli grup kükürt içerir: –SH (tiyol). (s. 13)",
        "en": "The marked group contains sulfur: –SH (thiol). (p. 13)",
        "fa": "گروه علامت‌خورده گوگرد دارد: –SH (تیول). (ص. 13)",
        "ar": "تحتوي المجموعة المحددة على الكبريت: –SH (ثيول). (ص. 13)"
      },
      {
        "tr": "Kuru öksürük tüm ACE inhibitörlerinde görülür, yani bu gruba özgü değildir.",
        "en": "Dry cough occurs with all ACE inhibitors, so it isn't specific to this group.",
        "fa": "سرفهٔ خشک در همهٔ مهارکننده‌های ACE دیده می‌شود، پس مختص این گروه نیست.",
        "ar": "يظهر السعال الجاف مع جميع مثبطات ACE، فهو ليس خاصًا بهذه المجموعة."
      },
      {
        "tr": "Bu yan etki ağızda hissedilir ve ciltte görülür.",
        "en": "This side effect is felt in the mouth and seen on the skin.",
        "fa": "این عارضه در دهان حس می‌شود و روی پوست دیده می‌شود.",
        "ar": "يُحَسّ هذا الأثر الجانبي في الفم ويظهر على الجلد."
      }
    ],
    "molecule": "captopril"
  }
];
