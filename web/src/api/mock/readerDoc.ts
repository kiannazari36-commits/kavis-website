// The teacher's PDF text, kept in its own language (Turkish), from design/NewIPad.dc.html (reader).
// Labels such as "page", "tag" and "end" are keys in src/i18n/reader.json.
import type { ReaderDoc } from '../types';

export const HYPERTENSION_DOC: ReaderDoc = {
  "id": "hypertension",
  "language": "tr",
  "title": "Hipertansiyon",
  "course": "FARMAKOTERAPİ",
  "pages": 48,
  "page": 12,
  "sections": [
    {
      "tab": "1 · Tanım",
      "blocks": [
        {
          "page": "s1page",
          "tag": "s1tag",
          "tagStyle": "vio",
          "heading": "Hipertansiyon nedir?",
          "paragraphs": [
            [
              "Hipertansiyon, tekrarlanan ölçümlerde sistolik kan basıncının 140 mmHg veya diyastolik kan basıncının 90 mmHg ve üzerinde olmasıdır. Vakaların çoğu ",
              {
                "term": "t4",
                "text": "primer hipertansiyon"
              },
              " grubundadır."
            ],
            [
              "Sekonder hipertansiyonda ise böbrek hastalığı, endokrin bozukluklar veya bazı ilaçlar gibi belirli bir neden vardır; neden tedavi edilince tansiyon düzelebilir."
            ]
          ]
        }
      ],
      "end": "s1end"
    },
    {
      "tab": "2 · İlaç tedavisi",
      "blocks": [
        {
          "page": "page12",
          "tag": "tagDose",
          "tagStyle": "vio",
          "paragraphs": [
            [
              "İlk basamak tedavide ",
              {
                "term": "t1",
                "text": "Diüretikler"
              },
              ", ",
              {
                "term": "t2",
                "text": "ACE inhibitörleri"
              },
              ", anjiyotensin reseptör blokerleri (ARB) ve kalsiyum kanal blokerleri kullanılır."
            ],
            {
              "selectable": true,
              "text": "ACE inhibitörlerine düşük dozla başlanır (ör. ramipril 2,5 mg/gün) ve doz 2–4 haftada bir titre edilir."
            }
          ],
          "molecule": true
        },
        {
          "page": "page13",
          "tag": "tagSide",
          "tagStyle": "red",
          "paragraphs": [
            [
              "Alfa-1 blokerlerin ilk dozundan sonra ",
              {
                "term": "t3",
                "text": "Ortostatik hipotansiyon"
              },
              " görülebilir; ilk dozun yatmadan önce alınması önerilir."
            ]
          ],
          "audio": true
        }
      ],
      "end": "checkSub"
    },
    {
      "tab": "3 · Özel durumlar",
      "blocks": [
        {
          "page": "s3page",
          "tag": "s3tag",
          "tagStyle": "vio",
          "heading": "Özel durumlar",
          "paragraphs": [
            [
              "Gebelikte metildopa, labetalol ve nifedipin tercih edilir. ACE inhibitörleri ve ARB'ler fetüse zarar verdiği için gebelikte ",
              {
                "term": "t6",
                "text": "kontrendike"
              },
              "dir."
            ],
            [
              "Diyabetik hastalarda böbreği koruduğu için ilk seçenek ACE inhibitörü veya ARB'dir. Yaşlılarda düşük dozla başlanır ve ortostatik hipotansiyon açısından izlenir."
            ]
          ]
        }
      ],
      "end": "s3end"
    },
    {
      "tab": "4 · Hipertansif kriz",
      "blocks": [
        {
          "page": "s4page",
          "tag": "s4tag",
          "tagStyle": "red",
          "heading": "Hipertansif kriz",
          "paragraphs": [
            [
              "Kan basıncı 180/120 mmHg'nin üzerindeyse ve ",
              {
                "term": "t7",
                "text": "hedef organ hasarı"
              },
              " varsa hipertansif acil durum vardır; tansiyon damar yoluyla ilaçla, ilk saatte en fazla %25 düşürülür."
            ],
            [
              "Organ hasarı yoksa (hipertansif ivedi durum) tansiyon ağızdan alınan ilaçlarla 24–48 saat içinde yavaşça düşürülür. Çok hızlı düşürmek beyin ve kalbe zarar verebilir."
            ]
          ]
        }
      ],
      "end": "s4end"
    }
  ],
  "terms": {
    "t1": {
      "page": 12,
      "en": "Diuretics"
    },
    "t2": {
      "page": 12,
      "en": "ACE inhibitors"
    },
    "t3": {
      "page": 13,
      "en": "Orthostatic hypotension"
    },
    "t4": {
      "page": 10,
      "en": "Primary (essential) hypertension"
    },
    "t6": {
      "page": 14,
      "en": "Contraindicated"
    },
    "t7": {
      "page": 16,
      "en": "Target organ damage"
    }
  },
  "sampleSentence": "İlk basamak tedavide Diüretikler, ACE inhibitörleri, anjiyotensin reseptör blokerleri (ARB) ve kalsiyum kanal blokerleri kullanılır.",
  "sampleTranslations": {
    "en": {
      "l": "English",
      "dir": "ltr",
      "lit": "First-line treatment Diuretics, ACE inhibitors, angiotensin receptor blockers (ARB) and calcium channel blockers are used.",
      "nat": "For first-line treatment, four drug groups are used: diuretics, ACE inhibitors, angiotensin receptor blockers (ARBs) and calcium channel blockers."
    },
    "fa": {
      "l": "فارسی",
      "dir": "rtl",
      "lit": "در درمان خط اول دیورتیک‌ها، مهارکننده‌های ACE، مسدودکننده‌های گیرنده آنژیوتانسین (ARB) و مسدودکننده‌های کانال کلسیم استفاده می‌شوند.",
      "nat": "برای شروع درمان، چهار گروه دارو به کار می‌رود: دیورتیک‌ها، مهارکننده‌های ACE، داروهای ARB و مسدودکننده‌های کانال کلسیم."
    },
    "ar": {
      "l": "العربية",
      "dir": "rtl",
      "lit": "في العلاج من الخط الأول تُستخدم مدرات البول، مثبطات ACE، حاصرات مستقبلات الأنجيوتنسين (ARB) وحاصرات قنوات الكالسيوم.",
      "nat": "في بداية العلاج نستخدم أربع مجموعات من الأدوية: مدرات البول، ومثبطات ACE، وحاصرات مستقبلات الأنجيوتنسين، وحاصرات قنوات الكالسيوم."
    }
  }
};
