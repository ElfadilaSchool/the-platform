// 📚 DICTIONNAIRE D'URGENCE COMPLET - MILIEU SCOLAIRE
// Couvre : Élèves + Personnel (enseignants, administratifs, direction)

const SCHOOL_COMPLETE_DICTIONARY = {
  
    // 🚨 URGENCE CRITIQUE (10/10) - INTERVENTION IMMÉDIATE ABSOLUE
    critical: {
      ar: [
        // === MORT / DÉCÈS ===
        'موت', 'وفاة', 'متوفي', 'ميت', 'توفي', 'مات',
        'موت موظف', 'وفاة موظف', 'موت طالب', 'وفاة طالب',
        
        // === DROGUES ===
        'تعاطي مخدرات', 'حيازة مخدرات', 'مخدرات', 'ترويج مخدرات', 'إدمان',
        'تعاطي مخدرات موظف', 'موظف تحت تأثير', 'طالب يتعاطى مخدرات',
        'مواد مشبوهة','مادة مشبوهة','مواد مخدرة','مخدر', 'حبوب مخدرة', 'مواد مخدرة', 'تجارة مخدرات',
        
        // === POSSESSION ARME BLANCHE ===
        'حيازة سلاح أبيض', 'سكين', 'موس', 'سلاح', 'طعن', 'تهديد بسلاح',
        'حمل سلاح', 'سلاح في المدرسة', 'مطواة', 'شفرة',
        
        // === ALCOOL ===
        'شرب كحول', 'سكر', 'حيازة كحول', 'كحول', 'مسكر',
        'شرب كحول في العمل', 'حالة سكر', 'موظف مخمور', 'طالب مخمور',
        'خمر', 'مشروبات كحولية', 'حالة سكر', 'ثمل', 'مخمور',
        
        // === TENTATIVE SUICIDE ===
        'محاولة انتحار', 'تهديد بالانتحار', 'انتحار', 'أفكار انتحارية',
        'رغبة في الموت', 'يريد الموت', 'يريد الانتحار', 'سينتحر',
        'موظف يريد الانتحار', 'طالب يريد الانتحار', 'تهديد بقتل نفسه'
      ],
      
      fr: [
        // === MORT / DÉCÈS ===
        'mort', 'décès', 'décédé', 'est mort', 'mourir',
        'mort employé', 'décès employé', 'mort élève', 'décès élève',
        
        // === DROGUES ===
        'consommation drogue', 'possession drogue', 'drogue', 'trafic drogue', 'addiction',
        'employé drogue', 'employé sous influence', 'élève consomme drogue',
        'stupéfiant', 'comprimés drogue', 'substances illicites', 'deal drogue',
        
        // === POSSESSION ARME BLANCHE ===
        'possession couteau', 'couteau', 'lame', 'arme', 'coup de couteau', 'menace arme',
        'port arme', 'arme école', 'cutter', 'rasoir',
        
        // === ALCOOL ===
        'alcool', 'ivre', 'possession alcool', 'bouteille alcool', 'état ébriété',
        'alcool travail', 'employé ivre', 'élève ivre',
        'vin', 'boissons alcoolisées', 'saoul', 'bourré',
        
        // === TENTATIVE SUICIDE ===
        'tentative suicide', 'menace suicide', 'suicide', 'idées suicidaires',
        'envie mourir', 'veut mourir', 'veut suicide', 'va se suicider',
        'employé veut suicide', 'élève veut suicide', 'menace se tuer'
      ],
      
      level: 'حرج جدا',
      levelFr: 'critique absolu',
      score: 10
    },
  
    // 🔴 URGENCE TRÈS ÉLEVÉE (8-9/10) - Intervention immédiate/dans l'heure
    veryHigh: {
      ar: [
        // === ÉLÈVES - URGENCES MÉDICALES GRAVES ===
        'سقط', 'وقع', 'فاقد الوعي', 'إغماء', 'نزيف', 'كسر', 'إصابة خطيرة', 'حساسية شديدة',
        'أزمة ربو', 'اختناق', 'صعوبة تنفس', 'ألم شديد', 'تشنجات', 'صرع',
        'مريض', 'حمى شديدة', 'قيء متكرر', 'إسهال حاد', 'صداع شديد', 'دوخة',
        
        // === ÉLÈVES - VIOLENCE PHYSIQUE GRAVE ===
        'ضرب مبرح', 'اعتداء جسدي خطير', 'عنف شديد', 'إصابة بجرح', 'نزيف دموي',
        'ضرب', 'شجار عنيف', 'مشاجرة', 'اعتداء', 'عنف', 'تنمر جسدي شديد',
        
        // === ÉLÈVES - DANGER IMMINENT ===
        'حريق', 'خطر محدق', 'هروب من المدرسة', 'اختطاف',
        'تحرش جنسي', 'اعتداء جنسي', 'اغتصاب',
        'هروب من الفصل', 'تخريب متعمد', 'سرقة', 'تهديد بالعنف',
        'سلوك عدواني خطير', 'حالة غير طبيعية',
        
        // === EMPLOYÉS - URGENCES MÉDICALES ===
        'موظف فاقد الوعي', 'أستاذ مريض بشدة', 'نوبة قلبية', 'سكتة دماغية', 'حادث عمل',
        'إصابة أثناء العمل', 'موظف سقط', 'نزيف موظف',
        
        // === EMPLOYÉS - VIOLENCE ET AGRESSIONS ===
        'اعتداء على موظف', 'عنف ضد أستاذ', 'ضرب موظف', 'تهديد بالقتل', 'تهديد جسدي خطير',
        'اعتداء جنسي على موظف', 'تحرش جنسي بموظف',
        'صراع عنيف بين موظفين', 'شجار بين أساتذة', 'خلاف حاد مع المدير',
        'تهديد موظف', 'مضايقة خطيرة', 'تحرش لفظي فاحش',
        
        // === EMPLOYÉS - INFRACTIONS GRAVES ===
        'سرقة خطيرة', 'اختلاس', 'فساد مالي', 'تزوير وثائق رسمية', 'ابتزاز',
        'فضيحة', 'تسريب معلومات سرية',
        'غياب غير مبرر متكرر', 'ترك العمل فجأة', 'رفض العمل', 'تمرد على الإدارة',
        'إهانة مدير', 'عصيان', 'انتهاك خطير للقوانين',
        'سلوك غير لائق فاضح',
        
        // === EMPLOYÉS - SANTÉ MENTALE GRAVE ===
        'انهيار عصبي', 'أزمة نفسية حادة', 'موظف في حالة هستيريا'
      ],
      
      fr: [
        // === ÉLÈVES - URGENCES MÉDICALES GRAVES ===
        'tombé', 'chute', 'inconscient', 'évanouissement', 'saignement', 'fracture', 
        'blessure grave', 'allergie sévère', 'crise asthme', 'étouffement', 'difficulté respirer',
        'douleur intense', 'convulsions', 'épilepsie',
        'malade', 'fièvre élevée', 'vomissements répétés', 'diarrhée sévère', 'migraine',
        'vertige',
        
        // === ÉLÈVES - VIOLENCE PHYSIQUE GRAVE ===
        'coups violents', 'agression grave', 'violence extrême', 
        'plaie ouverte', 'hémorragie', 'frappé', 'bagarre violente', 'agression', 
        'violence', 'intimidation sévère',
        
        // === ÉLÈVES - DANGER IMMINENT ===
        'incendie', 'danger imminent', 'fugue', 'enlèvement',
        'harcèlement sexuel', 'agression sexuelle', 'viol',
        'fuite classe', 'vandalisme', 'vol', 'menace violence',
        'comportement agressif dangereux', 'état anormal',
        
        // === EMPLOYÉS - URGENCES MÉDICALES ===
        'employé inconscient', 'enseignant gravement malade', 'crise cardiaque', 'AVC',
        'accident travail', 'blessure travail', 'employé tombé', 'saignement employé',
        
        // === EMPLOYÉS - VIOLENCE ET AGRESSIONS ===
        'agression employé', 'violence enseignant', 'employé frappé', 'menace mort',
        'menace physique grave', 'agression sexuelle employé', 'harcèlement sexuel employé',
        'conflit violent personnel', 'bagarre enseignants', 'conflit grave direction',
        'menace employé', 'harcèlement sérieux', 'harcèlement verbal obscène',
        
        // === EMPLOYÉS - INFRACTIONS GRAVES ===
        'vol grave', 'détournement fonds', 'corruption', 'falsification documents', 'chantage',
        'scandale', 'fuite informations confidentielles',
        'absences injustifiées répétées', 'abandon poste', 'refus travail', 'insubordination',
        'insulte direction', 'rébellion', 'violation grave règlement',
        'comportement indécent grave',
        
        // === EMPLOYÉS - SANTÉ MENTALE GRAVE ===
        'crise nerfs', 'crise psychologique aiguë', 'employé hystérie'
      ],
      
      level: 'عالي جدا',
      levelFr: 'très urgent',
      score: 9
    },
  
    // 🟠 URGENCE ÉLEVÉE (6-7/10) - Action dans la journée
    high: {
      ar: [
        // === ÉLÈVES ===
        'تحرش', 'مضايقة مستمرة', 'تنمر نفسي', 'إهانة متكررة', 'تهديد', 'ابتزاز',
        'عزل اجتماعي', 'إشاعات', 'عصيان', 'سوء سلوك متكرر', 'إزعاج متواصل',
        'قلق شديد', 'حزن واضح', 'تغير مفاجئ في السلوك', 'انعزال', 'بكاء متكرر',
        'غياب متكرر', 'تأخر متكرر', 'هروب متكرر',
        
        // === EMPLOYÉS ===
        'تحرش معنوي', 'مضايقة في العمل', 'تنمر من زميل', 'إهانة من رئيس',
        'تمييز', 'عنصرية', 'إقصاء متعمد', 'تهميش', 'استهداف موظف',
        'تأخر متكرر للموظف', 'إهمال في العمل', 'عدم احترام المواعيد', 'رفض التعاون',
        'صراع مع زملاء', 'خلاف مستمر', 'شكوى ضد موظف', 'تظلم',
        'سوء أداء متكرر', 'عدم كفاءة', 'إهمال الطلاب', 'عدم تحضير الدروس',
        'تأخر في التصحيح', 'عدم احترام البرنامج', 'غش في الامتحانات',
        'محاباة', 'تفضيل طلاب', 'علاقة غير مهنية مع طالب'
      ],
      
      fr: [
        // === ÉLÈVES ===
        'harcèlement', 'intimidation continue', 'harcèlement moral', 'insultes répétées',
        'menaces', 'chantage', 'exclusion sociale', 'rumeurs', 'insubordination',
        'comportement récurrent', 'perturbation continue', 'anxiété sévère', 'tristesse visible',
        'changement comportement', 'isolement', 'pleurs fréquents', 'absences répétées',
        'retards répétés', 'fugues répétées',
        
        // === EMPLOYÉS ===
        'harcèlement moral', 'harcèlement travail', 'intimidation collègue', 'insulte supérieur',
        'discrimination', 'racisme', 'exclusion volontaire', 'marginalisation', 'ciblage employé',
        'retards répétés employé', 'négligence travail', 'non respect horaires', 'refus collaboration',
        'conflit collègues', 'désaccord permanent', 'plainte contre employé', 'réclamation',
        'mauvaise performance répétée', 'incompétence', 'négligence élèves', 'cours non préparés',
        'retard correction', 'non respect programme', 'tricherie examens',
        'favoritisme', 'préférence élèves', 'relation non professionnelle élève'
      ],
      
      level: 'عالي',
      levelFr: 'élevé',
      score: 7
    },
  
    // 🟡 URGENCE MOYENNE (4-5/10) - Action sous 2-3 jours
    medium: {
      ar: [
        // === ÉLÈVES ===
        'شكوى', 'مشكلة في الفصل', 'خلاف بين طلاب', 'نزاع صغير', 'نقاش حاد',
        'عدم تركيز', 'انخفاض الأداء', 'عدم إنجاز الواجبات', 'إهمال دراسي',
        'تأخر خفيف', 'غياب لمرة واحدة', 'نسيان الأدوات', 'صعوبة اندماج',
        
        // === EMPLOYÉS ===
        'خلاف بسيط', 'سوء تفاهم بين موظفين', 'توتر في العلاقات', 'نقاش حاد',
        'اختلاف في الرأي', 'صراع حول طريقة العمل',
        'تأخر في تسليم الوثائق', 'نسيان اجتماع', 'خطأ في التقرير', 'سوء تنظيم',
        'عدم التنسيق', 'قلة التواصل', 'نقص المعلومات',
        'طلب نقل', 'طلب إجازة', 'شكوى إدارية', 'طلب تغيير جدول', 'طلب دعم',
        'طلب تكوين', 'طلب ترقية', 'استفسار عن الراتب'
      ],
      
      fr: [
        // === ÉLÈVES ===
        'plainte', 'problème classe', 'conflit élèves', 'dispute mineure', 'discussion tendue',
        'manque concentration', 'baisse performance', 'devoirs non faits', 'négligence scolaire',
        'retard léger', 'absence ponctuelle', 'oubli matériel', 'difficulté intégration',
        
        // === EMPLOYÉS ===
        'désaccord mineur', 'malentendu employés', 'tension relations', 'discussion animée',
        'différence opinion', 'conflit méthode travail',
        'retard documents', 'oubli réunion', 'erreur rapport', 'mauvaise organisation',
        'manque coordination', 'communication insuffisante', 'manque information',
        'demande mutation', 'demande congé', 'plainte administrative', 'demande changement emploi temps',
        'demande soutien', 'demande formation', 'demande promotion', 'question salaire'
      ],
      
      level: 'متوسط',
      levelFr: 'moyen',
      score: 5
    },
  
    // 🟢 URGENCE FAIBLE (1-3/10) - Suivi de routine
    low: {
      ar: [
        // === ÉLÈVES ===
        'استفسار', 'طلب معلومات', 'سؤال', 'طلب شهادة', 'طلب وثيقة',
        'اقتراح', 'ملاحظة', 'رأي', 'تقييم إيجابي', 'شكر', 'تهنئة',
        'تقدم في الدراسة', 'تحسن السلوك', 'مشاركة جيدة', 'تفوق', 'نجاح',
        'نشاط خارجي', 'رحلة مدرسية', 'فعالية', 'مسابقة', 'احتفال',
        
        // === EMPLOYÉS ===
        'استفسار إداري', 'سؤال عن الإجراءات', 'طلب نموذج', 'طلب معلومة',
        'توضيح', 'تأكيد', 'إشعار', 'إعلام',
        'شكر موظف', 'تقدير', 'تهنئة بالترقية', 'تكريم', 'نجاح مشروع',
        'تحسن الأداء', 'إنجاز متميز', 'مبادرة إيجابية', 'تعاون ممتاز',
        'اجتماع دوري', 'تقرير روتيني', 'تحديث معلومات', 'إحصائيات',
        'جدول زمني', 'خطة عمل', 'برنامج', 'تقويم', 'جرد'
      ],
      
      fr: [
        // === ÉLÈVES ===
        'question', 'demande information', 'demande certificat', 'demande document',
        'suggestion', 'remarque', 'avis', 'évaluation positive', 'remerciement', 'félicitations',
        'progrès scolaire', 'amélioration comportement', 'bonne participation', 'excellence', 'réussite',
        'activité extrascolaire', 'sortie scolaire', 'événement', 'concours', 'célébration',
        
        // === EMPLOYÉS ===
        'question administrative', 'question procédures', 'demande formulaire', 'demande info',
        'clarification', 'confirmation', 'notification', 'information',
        'remerciement employé', 'reconnaissance', 'félicitations promotion', 'distinction', 'succès projet',
        'amélioration performance', 'réalisation remarquable', 'initiative positive', 'excellente collaboration',
        'réunion routine', 'rapport routine', 'mise à jour', 'statistiques',
        'planning', 'plan action', 'programme', 'calendrier', 'inventaire'
      ],
      
      level: 'منخفض',
      levelFr: 'faible',
      score: 2
    }
  };
  
  module.exports = { SCHOOL_COMPLETE_DICTIONARY };
  