const express = require('express');
const { v4: uuidv4 } = require('uuid');
const PDFDocument = require('pdfkit');
const fs = require('fs');
const dotenv = require('dotenv');
dotenv.config();
// Normalize and validate Gemini API key early (accept GEMINI_API_KEY or GOOGLE_API_KEY)
const stripInvisibles = (s) => (s || '').replace(/[\u200B-\u200F\u202A-\u202E\u2066-\u2069]/g, '');
const rawGeminiKey = process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY || '';
const normalizedGeminiKey = stripInvisibles(rawGeminiKey).trim();
process.env.GEMINI_API_KEY = normalizedGeminiKey;
if (!normalizedGeminiKey) {
  console.error('GEMINI_API_KEY is missing. Set GEMINI_API_KEY (or GOOGLE_API_KEY) in .env');
} else {
  const prefix = normalizedGeminiKey.slice(0, 4);
  console.log(`[Gemini] API key loaded (prefix): ${prefix}…`);
}
// Optional RTL/Arabic shaping support if available
let enablePdfRtl = false;
let arabicShaper = null;
let bidiProcessor = null;
try {
  // If the package is installed, this will augment PDFKit to shape Arabic/RTL
  require('pdfkit-rtl')(PDFDocument);
  enablePdfRtl = true;
  console.log('PDF RTL shaping enabled (pdfkit-rtl)');
} catch (_) {
  console.warn('pdfkit-rtl not found: falling back to Unicode bidi markers for Arabic');
}
// Try to enable advanced shaping using optional packages
try {
  // Prefer arabic-persian-reshaper
  arabicShaper = require('arabic-persian-reshaper');
} catch (_) {
  try {
    arabicShaper = require('arabic-reshaper');
  } catch (_) {}
}
try {
  bidiProcessor = require('bidi-js');
} catch (_) {}
const router = express.Router();
const pool = require('./db');

// Debug middleware for route logging
router.use((req, res, next) => {
  console.log(`[RAPPORTEMP] ${req.method} ${req.path} - Original URL: ${req.originalUrl}`);
  next();
});

// Test route to verify router is working
router.get('/test', (req, res) => {
  res.json({ success: true, message: 'Rapportemp router is working!' });
});

const { GoogleGenerativeAI } = require("@google/generative-ai");

// Initialise le client Gemini. La clé API est lue depuis process.env.GEMINI_API_KEY
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY)


// Configuration Gemini

const fetch = (...args) => import('node-fetch').then(({ default: fetch }) => fetch(...args));

// ========================================
// 🔥 IMPORTER LE DICTIONNAIRE
// ========================================
const { SCHOOL_COMPLETE_DICTIONARY } = require('./dictionary');

// ========================================
// 🔍 FONCTION 1: ANALYSE PAR DICTIONNAIRE
// ========================================
function analyzeBySeverityDictionary(content, title, subject) {
  const fullText = `${title} ${subject} ${content}`.toLowerCase();
  
  let highestScore = 0;
  let detectedLevel = 'low';
  let detectedLevelAr = 'منخفض';
  let detectedLevelFr = 'faible';
  let matchedKeywords = [];
  let detectedCategory = null;

  // Parcourir tous les niveaux de gravité
  for (const [categoryKey, categoryData] of Object.entries(SCHOOL_COMPLETE_DICTIONARY)) {
    const { ar, fr, score, level, levelFr } = categoryData;
    
    // Vérifier les mots-clés arabes
    for (const keyword of ar) {
      if (fullText.includes(keyword.toLowerCase())) {
        matchedKeywords.push(keyword);
        if (score > highestScore) {
          highestScore = score;
          detectedLevel = categoryKey;
          detectedLevelAr = level;
          detectedLevelFr = levelFr;
          detectedCategory = categoryKey;
        }
      }
    }
    
    // Vérifier les mots-clés français
    for (const keyword of fr) {
      if (fullText.includes(keyword.toLowerCase())) {
        matchedKeywords.push(keyword);
        if (score > highestScore) {
          highestScore = score;
          detectedLevel = categoryKey;
          detectedLevelAr = level;
          detectedLevelFr = levelFr;
          detectedCategory = categoryKey;
        }
      }
    }
  }

  // Dédupliquer les mots-clés
  matchedKeywords = [...new Set(matchedKeywords)];

  return {
    score: highestScore,
    level: detectedLevel,
    levelAr: detectedLevelAr,
    levelFr: detectedLevelFr,
    category: detectedCategory,
    matchedKeywords: matchedKeywords.slice(0, 10),
    method: 'dictionary'
  };
}


// ========================================
// 🤖 FONCTION 2: ANALYSE PAR IA GROQ (TON CODE EXISTANT)
// ========================================
async function analyzeWithGroq(content, title, subject) {
  try {
    const GROQ_KEY = process.env.GROQ_API_KEY;
    
    if (!GROQ_KEY) {
      throw new Error('GROQ_API_KEY manquante dans .env');
    }

    const contentLength = content.length;
    let summaryInstruction;
    
    if (contentLength < 500) {
      summaryInstruction = "résumé TRÈS COURT en arabe (1-2 phrases maximum)";
    } else if (contentLength < 1500) {
      summaryInstruction = "résumé COURT en arabe (2-3 phrases)";
    } else if (contentLength < 3000) {
      summaryInstruction = "résumé détaillé en arabe (3-4 phrases)";
    } else {
      summaryInstruction = "résumé détaillé et complet en arabe (4-6 phrases)";
    }

    const prompt = `Tu es un expert en analyse de rapports administratifs arabes. Analyse CE rapport précis et extrait les informations RÉELLES.

TITRE: ${title}
SUJET: ${subject}
CONTENU: ${content.substring(0, 3500)}

Retourne UNIQUEMENT un objet JSON avec cette structure exacte:

{
  "summary": "${summaryInstruction}",
  "sentiment": {
    "label": "إيجابي ou سلبي ou محايد",
    "score": 0.75
  },
  "entities": {
    "persons": ["noms des personnes RÉELLEMENT mentionnées"],
    "locations": ["lieux RÉELLEMENT mentionnés"],
    "organizations": ["organisations RÉELLEMENT mentionnées"],
    "dates": ["dates RÉELLEMENT mentionnées"]
  },
  "keywords": ["8-12 mots-clés RÉELLEMENT extraits du contenu"],
  "severity": {
    "level": "منخفضة (1-3) ou متوسطة (4-6) ou عالية (7-8) ou حرجة جدا (9-10)",
    "score": 5,
    "reasoning": "explication courte en français"
  },
  "urgency": {
    "level": "منخفض (1-3) ou متوسط (4-6) ou عالي (7-8) ou حرج جدا (9-10)",
    "score": 5,
    "reasoning": "explication courte en français"
  },
  "categories": ["catégories basées sur le VRAI contenu"]
}

RÈGLES CRITIQUES:
- Analyse le CONTENU RÉEL fourni, pas d'exemples fictifs
- Le résumé doit être proportionnel à la taille du rapport
- Si une entité n'existe pas dans le texte, laisse le tableau vide []
- Les scores doivent refléter le contenu analysé
- Réponds UNIQUEMENT avec le JSON, aucun texte avant ou après`;

    const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${GROQ_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: "llama-3.3-70b-versatile",
        messages: [
          {
            role: "system",
            content: "Tu es un expert en analyse de documents administratifs en arabe. Tu réponds UNIQUEMENT en JSON valide."
          },
          {
            role: "user",
            content: prompt
          }
        ],
        temperature: 0.3,
        max_tokens: 2000,
        top_p: 0.95
      })
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Groq API error ${response.status}: ${errorText}`);
    }

    const data = await response.json();
    const text = data.choices[0].message.content;

    let cleanText = text.trim()
      .replace(/```json\n?/g, '')
      .replace(/```\n?/g, '')
      .trim();
    
    const jsonMatch = cleanText.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      throw new Error("JSON non trouvé dans la réponse Groq");
    }

    const parsed = JSON.parse(jsonMatch[0]);
    
    return {
      ...parsed,
      metadata: {
        model: "llama-3.3-70b-versatile",
        provider: "groq",
        analyzed_at: new Date().toISOString(),
        content_length: content.length
      }
    };

  } catch (err) {
    console.error("❌ Erreur Groq:", err.message);
    throw err;
  }
}
// ========================================
// 🧠 FONCTION 3: ANALYSE HYBRIDE INTELLIGENTE
// ========================================
async function analyzeReportHybrid(content, title, subject) {
  console.log('\n🔬 === ANALYSE HYBRIDE DÉMARRÉE ===');
  
  try {
    // ÉTAPE 1: Analyse rapide par dictionnaire
    console.log('📖 Phase 1: Analyse par dictionnaire...');
    const dictionaryResult = analyzeBySeverityDictionary(content, title, subject);
    console.log(`✅ Dictionnaire: ${dictionaryResult.levelFr} (${dictionaryResult.score}/10)`);
    console.log(`🔑 Mots-clés détectés: ${dictionaryResult.matchedKeywords.length}`);

    // ÉTAPE 2: Analyse contextuelle par IA
    console.log('🤖 Phase 2: Analyse par IA Groq...');
    const groqResult = await analyzeWithGroq(content, title, subject);
    console.log(`✅ IA: Gravité ${groqResult.severity.score}/10, Urgence ${groqResult.urgency.score}/10`);

    // ÉTAPE 3: FUSION INTELLIGENTE DES RÉSULTATS
    console.log('🔀 Phase 3: Fusion des analyses...');
    
    let finalSeverity, finalUrgency;
    
    if (dictionaryResult.category === 'critical') {
      // CAS CRITIQUE: Le dictionnaire a détecté des mots-clés de danger absolu
      finalSeverity = {
        score: 10,
        level: 'حرجة للغاية',
        levelFr: 'critique absolu',
        source: 'dictionary_override',
        reasoning: `🚨 Détection automatique: ${dictionaryResult.matchedKeywords.slice(0, 3).join(', ')}`,
        dictionary_match: true,
        ai_score: groqResult.severity.score
      };
      finalUrgency = {
        score: 10,
        level: 'حرج جدا',
        levelFr: 'urgence maximale',
        source: 'dictionary_override',
        reasoning: '⚠️ Intervention immédiate requise',
        dictionary_match: true,
        ai_score: groqResult.urgency.score
      };
    } else if (dictionaryResult.category === 'veryHigh') {
      // CAS TRÈS ÉLEVÉ: On prend le max entre dictionnaire et IA
      finalSeverity = {
        score: Math.max(dictionaryResult.score, groqResult.severity.score),
        level: dictionaryResult.score >= groqResult.severity.score ? dictionaryResult.levelAr : groqResult.severity.level,
        levelFr: dictionaryResult.score >= groqResult.severity.score ? dictionaryResult.levelFr : 'très élevée',
        source: dictionaryResult.score >= groqResult.severity.score ? 'dictionary_priority' : 'ai_priority',
        reasoning: groqResult.severity.reasoning || `Mots-clés: ${dictionaryResult.matchedKeywords.slice(0, 2).join(', ')}`,
        dictionary_match: true,
        ai_score: groqResult.severity.score,
        dictionary_score: dictionaryResult.score
      };
      finalUrgency = {
        score: Math.max(dictionaryResult.score, groqResult.urgency.score),
        level: groqResult.urgency.level,
        levelFr: 'très urgent',
        source: 'hybrid',
        reasoning: groqResult.urgency.reasoning || 'Action requise dans l\'heure',
        dictionary_match: true
      };
    } else if (dictionaryResult.score > 0) {
      // CAS MOYEN/ÉLEVÉ: On pondère dictionnaire (40%) + IA (60%)
      const weightedScore = Math.round(
        (dictionaryResult.score * 0.4) + (groqResult.severity.score * 0.6)
      );
      finalSeverity = {
        score: weightedScore,
        level: groqResult.severity.level,
        levelFr: dictionaryResult.levelFr,
        source: 'weighted_hybrid',
        reasoning: groqResult.severity.reasoning,
        dictionary_match: true,
        ai_score: groqResult.severity.score,
        dictionary_score: dictionaryResult.score
      };
      finalUrgency = {
        score: Math.round((dictionaryResult.score * 0.3) + (groqResult.urgency.score * 0.7)),
        level: groqResult.urgency.level,
        levelFr: dictionaryResult.levelFr,
        source: 'weighted_hybrid',
        reasoning: groqResult.urgency.reasoning,
        dictionary_match: true
      };
    } else {
      // CAS STANDARD: Aucun mot-clé détecté, on se fie à l'IA
      finalSeverity = {
        ...groqResult.severity,
        source: 'ai_only',
        dictionary_match: false,
        dictionary_score: 0
      };
      finalUrgency = {
        ...groqResult.urgency,
        source: 'ai_only',
        dictionary_match: false
      };
    }

    // RÉSULTAT FINAL
    const finalResult = {
      summary: groqResult.summary,
      sentiment: groqResult.sentiment,
      entities: groqResult.entities,
      keywords: [
        ...dictionaryResult.matchedKeywords,
        ...groqResult.keywords
      ].slice(0, 15),
      severity: finalSeverity,
      urgency: finalUrgency,
      categories: groqResult.categories,
      analysis_method: {
        dictionary_detected: dictionaryResult.category || 'none',
        dictionary_keywords_count: dictionaryResult.matchedKeywords.length,
        ai_provider: 'groq',
        fusion_strategy: finalSeverity.source
      },
      metadata: {
        ...groqResult.metadata,
        dictionary_version: '1.0',
        hybrid_analysis: true
      }
    };

    console.log('✅ === ANALYSE HYBRIDE TERMINÉE ===');
    console.log(`📊 Gravité finale: ${finalSeverity.score}/10 (${finalSeverity.source})`);
    console.log(`⏰ Urgence finale: ${finalUrgency.score}/10 (${finalUrgency.source})`);
    
    return finalResult;

  } catch (error) {
    console.error('❌ Erreur analyse hybride:', error.message);
    
    // FALLBACK: Si l'IA échoue, utiliser UNIQUEMENT le dictionnaire
    const dictionaryResult = analyzeBySeverityDictionary(content, title, subject);
    
    return {
      summary: "تعذر التحليل الكامل. تم استخدام التحليل التلقائي فقط.",
      sentiment: { label: "محايد", score: 0.5 },
      entities: { persons: [], locations: [], organizations: [], dates: [] },
      keywords: dictionaryResult.matchedKeywords,
      severity: {
        score: dictionaryResult.score,
        level: dictionaryResult.levelAr,
        levelFr: dictionaryResult.levelFr,
        source: 'dictionary_fallback',
        reasoning: `Détection automatique: ${dictionaryResult.matchedKeywords.slice(0, 3).join(', ')}`,
        dictionary_match: true
      },
      urgency: {
        score: dictionaryResult.score,
        level: dictionaryResult.levelAr,
        levelFr: dictionaryResult.levelFr,
        source: 'dictionary_fallback',
        dictionary_match: true
      },
      categories: [dictionaryResult.category || 'général'],
      analysis_method: {
        dictionary_detected: dictionaryResult.category,
        dictionary_keywords_count: dictionaryResult.matchedKeywords.length,
        ai_provider: 'none',
        fusion_strategy: 'dictionary_only'
      },
      metadata: {
        error: error.message,
        fallback: true,
        dictionary_only: true,
        analyzed_at: new Date().toISOString()
      }
    };
  }
}

// Fallback en cas d'erreur totale
function generateFallbackAnalysis(content) {
  const isArabic = /[\u0600-\u06FF]/.test(content);
  
  return {
    summary: isArabic ? 
      "تحليل غير متوفر مؤقتًا. المحتوى يتطلب مراجعة يدوية." :
      "Analyse temporairement indisponible. Contenu nécessite une revue manuelle.",
    sentiment: { label: isArabic ? "محايد" : "neutre", score: 0.5 },
    entities: { persons: [], locations: [], organizations: [], dates: [] },
    keywords: [],
    severity: { level: isArabic ? "غير محدد" : "non déterminé", score: 0 },
    urgency: { level: isArabic ? "غير محدد" : "non déterminé", score: 0 },
    categories: [isArabic ? "تقرير عام" : "rapport général"],
    metadata: { analyzed_at: new Date().toISOString(), fallback: true }
  };
}


// 📝 Créer un nouveau rapport
router.post('/create', async (req, res) => {
  try {
    const {
      employee_id,
      title,
      subject,
      content,
      recipients,
      include_director,
      concerned_employees
    } = req.body;

    const isUuid = (value) =>
      typeof value === 'string' &&
      /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$/.test(value);

    if (!employee_id || !title || !subject || !content) {
      return res.status(400).json({ error: 'Champs requis manquants' });
    }

    const safeRecipients = Array.isArray(recipients) ? recipients.filter(isUuid) : [];
    const safeConcerned = Array.isArray(concerned_employees) ? concerned_employees.filter(isUuid) : [];
    const includeDirectorFlag = true;

    if (safeRecipients.length === 0 && !includeDirectorFlag) {
      return res.status(400).json({ error: 'Au moins un destinataire valide doit être sélectionné (ou inclure le directeur)' });
    }

    const senderIsResponsibleResult = await pool.query(
      `SELECT EXISTS(SELECT 1 FROM departments d WHERE d.responsible_id = $1) AS is_resp`,
      [employee_id]
    );
    const senderIsResponsible = senderIsResponsibleResult.rows[0]?.is_resp === true;

    let validRecipients = [...safeRecipients];

    if (senderIsResponsible) {
      if (validRecipients.length > 0) {
        const respCheck = await pool.query(
          `SELECT e.id FROM employees e WHERE e.id = ANY($1::uuid[]) AND EXISTS(SELECT 1 FROM departments d WHERE d.responsible_id = e.id)`,
          [validRecipients]
        );
        const allowedSet = new Set(respCheck.rows.map((r) => r.id));
        const invalid = validRecipients.filter((id) => !allowedSet.has(id));
        if (invalid.length > 0) {
          return res.status(400).json({
            error: "Un responsable ne peut envoyer qu'à d'autres responsables",
            invalid_recipient_ids: invalid
          });
        }
      }
    } else {
      const respRes = await pool.query(`
        SELECT DISTINCT d.responsible_id AS id
        FROM employee_departments ed
        JOIN departments d ON d.id = ed.department_id
        WHERE ed.employee_id = $1 AND d.responsible_id IS NOT NULL
      `, [employee_id]);
      const employeeResponsibles = new Set(respRes.rows.map((r) => r.id));

      if (validRecipients.length > 0) {
        const invalid = validRecipients.filter((id) => !employeeResponsibles.has(id));
        if (invalid.length > 0) {
          return res.status(400).json({
            error: 'Un employé ne peut envoyer qu’à son responsable (ou uniquement au directeur)',
            invalid_recipient_ids: invalid
          });
        }
      }
      if (respRes.rows.length === 0) {
        validRecipients = [];
      }
    }

    // Append closing based on language (Arabic vs French)
    const contentIsArabic = /[\u0600-\u06FF]/.test(content || '');
    const closingFr = 'Cordialement,';
    const closingAr = 'مع فائق الاحترام,';
    const finalContent = `${content}\n\n${contentIsArabic ? closingAr : closingFr}`;

    let remarks = '';
    const destinataires = [];

    if (validRecipients.length > 0) {
      for (const id of validRecipients) {
        try {
          const result = await pool.query(`
            SELECT e.first_name, e.last_name, d.name as department_name
            FROM employees e
            LEFT JOIN departments d ON d.responsible_id = e.id
            WHERE e.id = $1
          `, [id]);
          if (result.rows.length > 0) {
            const resp = result.rows[0];
            const name = `${resp.first_name} ${resp.last_name}`;
            const fullName = resp.department_name ? `${name} (${resp.department_name})` : name;
            destinataires.push(fullName);
          }
        } catch (error) {
          console.error('Erreur récupération responsable:', error);
        }
      }
    }

    if (includeDirectorFlag && destinataires.length > 0) {
      remarks = `Destinataires: Directeur Général, ${destinataires.join(', ')}`;
    } else if (includeDirectorFlag) {
      remarks = 'Destinataire: Directeur Général';
    } else if (destinataires.length > 0) {
      remarks = `Destinataires: ${destinataires.join(', ')}`;
    }

    if (safeConcerned.length > 0) {
      try {
        const employeeResult = await pool.query(`
          SELECT id, first_name, last_name 
          FROM employees 
          WHERE id = ANY($1::uuid[])
        `, [safeConcerned]);

        const employeeNames = employeeResult.rows.map(emp => `${emp.first_name} ${emp.last_name}`);
        remarks += ` | Employés concernés: ${employeeNames.join(', ')}`;
      } catch (error) {
        console.error('Erreur récupération noms employés:', error);
      }
    }

    const reportId = uuidv4();
    const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.TASK_SERVICE_PORT || 3020}`;
    const pdfUrl = `${baseUrl}/api/rapportemp/${reportId}/pdf`;

    // 🔹 INSERT rapport avec remarks mais sans analysis
    const result = await pool.query(`
      INSERT INTO employee_reports 
        (id, employee_id, title, subject, content, recipients, include_director, concerned_employees, remarks, pdf_url, status)
      VALUES ($1, $2, $3, $4, $5, $6::uuid[], $7, $8::uuid[], $9, $10, $11)
      RETURNING *
    `, [
      reportId,
      employee_id,
      title,
      subject,
      finalContent,
      validRecipients.length > 0 ? validRecipients : null,
      includeDirectorFlag,
      safeConcerned.length > 0 ? safeConcerned : null,
      remarks,
      pdfUrl,
      'pending'
    ]);

    const newReport = result.rows[0];

    // Répondre immédiatement
    res.status(201).json({
      success: true,
      report: newReport,
      message: 'Rapport créé. Analyse en arrière-plan.'
    });
// ==== REMPLACER TOUT LE BLOC setImmediate ====
setImmediate(async () => {
  console.log('\n🚀 === LANCEMENT ANALYSE HYBRIDE ===');
  console.log(`📄 Rapport ID: ${newReport.id}`);
  console.log(`📋 Titre: ${newReport.title}`);
  
  try {
    // 🔥 UTILISATION DU SYSTÈME HYBRIDE
    const analysis = await analyzeReportHybrid(
      newReport.content,
      newReport.title,
      newReport.subject
    );
    
    console.log('\n✅ === ANALYSE RÉUSSIE ===');
    console.log('📝 Résumé:', analysis.summary?.substring(0, 100) + '...');
    console.log('😊 Sentiment:', analysis.sentiment.label, `(${(analysis.sentiment.score * 100).toFixed(1)}%)`);
    console.log('⚠️  Gravité:', analysis.severity.level, `(${analysis.severity.score}/10)`);
    console.log('⏰ Urgence:', analysis.urgency.level, `(${analysis.urgency.score}/10)`);
    console.log('🔍 Méthode:', analysis.analysis_method.fusion_strategy);
    console.log('🔑 Mots-clés:', analysis.keywords.length);
    
    // Sauvegarde en base
    await pool.query(
      'UPDATE employee_reports SET analysis = $1, updated_at = NOW() WHERE id = $2',
      [JSON.stringify(analysis), newReport.id]
    );
    
    console.log('💾 Analyse sauvegardée en base de données');
    
    // 🚨 ALERTE SI CRITIQUE OU TRÈS ÉLEVÉ
    if (analysis.severity.score >= 9 || analysis.urgency.score >= 9) {
      console.log('\n🚨 === ALERTE CRITIQUE DÉTECTÉE ===');
      console.log('📧 Envoi de notification urgente...');
      
      // Tu peux ajouter ici ton système de notification
      // await sendCriticalAlert(newReport, analysis);
    }
    
  } catch (error) {
    console.error('\n❌ === ERREUR CRITIQUE ANALYSE ===');
    console.error('Message:', error.message);
    console.error('Stack:', error.stack);
    
    // Fallback garanti
    const fallbackAnalysis = generateFallbackAnalysis(newReport.content);
    
    await pool.query(
      'UPDATE employee_reports SET analysis = $1, updated_at = NOW() WHERE id = $2',
      [JSON.stringify(fallbackAnalysis), newReport.id]
    );
    
    console.log('🛡️  Analyse de fallback sauvegardée');
  }
});

} catch (error) {
console.error('❌ Erreur création rapport:', error);
res.status(500).json({
  error: 'Impossible de créer le rapport',
  details: error.message
});
}
});
// ==== FIN DU REMPLACEMENT ====
    // Fonction utilitaire pour sauvegarder les entités
    function saveEntity(entity, entities) {
      if (entity.score < 0.5) return; // Seuil de confiance
      
      const text = entity.text.trim();
      if (text.length < 2) return;
      
      switch(entity.type) {
        case 'PER':
          entities.persons.push(text);
          break;
        case 'LOC':
          entities.locations.push(text);
          break;
        case 'ORG':
          entities.organizations.push(text);
          break;
        default:
          entities.misc.push(text);
      }
    }
// ========================================
// 🔧 FONCTIONS UTILITAIRES SUPPLÉMENTAIRES
// ========================================

/**
 * Fonction pour récupérer l'analyse d'un rapport
 */
async function getReportAnalysis(reportId) {
  try {
    const result = await pool.query(
      'SELECT analysis FROM employee_reports WHERE id = $1',
      [reportId]
    );
    
    if (result.rows.length === 0) {
      return null;
    }
    
    return result.rows[0].analysis;
  } catch (error) {
    console.error('❌ Erreur récupération analyse:', error);
    return null;
  }
}

/**
 * Fonction pour comparer la gravité de plusieurs rapports
 */
function compareReportsSeverity(analyses) {
  const severityOrder = {
    'très élevée': 4, 'عالية جدا': 4,
    'élevée': 3, 'عالية': 3,
    'moyenne': 2, 'متوسطة': 2,
    'faible': 1, 'منخفضة': 1,
    'non déterminé': 0, 'غير محدد': 0
  };
  
  return analyses.sort((a, b) => {
    const scoreA = a.signals?.severity_score || severityOrder[a.signals?.severity] || 0;
    const scoreB = b.signals?.severity_score || severityOrder[b.signals?.severity] || 0;
    return scoreB - scoreA;
  });
}

/**
 * Fonction pour extraire les rapports urgents du jour
 */
async function getUrgentReportsToday() {
  try {
    const result = await pool.query(`
      SELECT id, title, subject, analysis, created_at
      FROM employee_reports
      WHERE DATE(created_at) = CURRENT_DATE
      AND analysis IS NOT NULL
      ORDER BY created_at DESC
    `);
    
    const urgentReports = result.rows.filter(report => {
      if (!report.analysis) return false;
      const analysis = typeof report.analysis === 'string' 
        ? JSON.parse(report.analysis) 
        : report.analysis;
      
      const urgency = analysis.signals?.urgency;
      return urgency === 'élevée' || urgency === 'très élevée' || 
             urgency === 'عالية' || urgency === 'عالية جدا';
    });
    
    return urgentReports;
  } catch (error) {
    console.error('❌ Erreur récupération rapports urgents:', error);
    return [];
  }
}

/**
 * Fonction pour générer un rapport statistique mensuel
 */
async function getMonthlyStatistics() {
  try {
    const result = await pool.query(`
      SELECT analysis, created_at
      FROM employee_reports
      WHERE created_at >= DATE_TRUNC('month', CURRENT_DATE)
      AND analysis IS NOT NULL
    `);
    
    const stats = {
      total: result.rows.length,
      by_severity: { 'très élevée': 0, 'élevée': 0, 'moyenne': 0, 'faible': 0 },
      by_urgency: { 'très élevée': 0, 'élevée': 0, 'moyenne': 0, 'faible': 0 },
      by_sentiment: { 'positif': 0, 'négatif': 0, 'neutre': 0 },
      top_categories: {},
      top_keywords: {},
      average_severity_score: 0,
      average_urgency_score: 0
    };
    
    let totalSeverityScore = 0;
    let totalUrgencyScore = 0;
    
    result.rows.forEach(row => {
      const analysis = typeof row.analysis === 'string' 
        ? JSON.parse(row.analysis) 
        : row.analysis;
      
      // Gravité
      const severity = analysis.signals?.severity;
      const severityMap = {
        'très élevée': 'très élevée', 'عالية جدا': 'très élevée',
        'élevée': 'élevée', 'عالية': 'élevée',
        'moyenne': 'moyenne', 'متوسطة': 'moyenne',
        'faible': 'faible', 'منخفضة': 'faible'
      };
      const mappedSeverity = severityMap[severity] || 'faible';
      stats.by_severity[mappedSeverity] = (stats.by_severity[mappedSeverity] || 0) + 1;
      totalSeverityScore += analysis.signals?.severity_score || 0;
      
      // Urgence
      const urgency = analysis.signals?.urgency;
      const mappedUrgency = severityMap[urgency] || 'faible';
      stats.by_urgency[mappedUrgency] = (stats.by_urgency[mappedUrgency] || 0) + 1;
      totalUrgencyScore += analysis.signals?.urgency_score || 0;
      
      // Sentiment
      const sentiment = analysis.sentiment?.label;
      const sentimentMap = {
        'positif': 'positif', 'إيجابي': 'positif',
        'négatif': 'négatif', 'سلبي': 'négatif',
        'neutre': 'neutre', 'محايد': 'neutre'
      };
      const mappedSentiment = sentimentMap[sentiment] || 'neutre';
      stats.by_sentiment[mappedSentiment] = (stats.by_sentiment[mappedSentiment] || 0) + 1;
      
      // Catégories
      (analysis.categories || []).forEach(category => {
        stats.top_categories[category] = (stats.top_categories[category] || 0) + 1;
      });
      
      // Mots-clés
      (analysis.keywords || []).forEach(keyword => {
        stats.top_keywords[keyword] = (stats.top_keywords[keyword] || 0) + 1;
      });
    });
    
    // Moyennes
    if (result.rows.length > 0) {
      stats.average_severity_score = (totalSeverityScore / result.rows.length).toFixed(2);
      stats.average_urgency_score = (totalUrgencyScore / result.rows.length).toFixed(2);
    }
    
    // Top 10 catégories
    stats.top_categories = Object.entries(stats.top_categories)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .reduce((obj, [key, val]) => ({ ...obj, [key]: val }), {});
    
    // Top 15 mots-clés
    stats.top_keywords = Object.entries(stats.top_keywords)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 15)
      .reduce((obj, [key, val]) => ({ ...obj, [key]: val }), {});
    
    return stats;
  } catch (error) {
    console.error('❌ Erreur statistiques mensuelles:', error);
    return null;
  }
}

// ========================================
// 📡 ROUTES API SUPPLÉMENTAIRES
// ========================================

// Route pour récupérer l'analyse d'un rapport
router.get('/:id/analysis', async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await pool.query(
      'SELECT analysis FROM employee_reports WHERE id = $1',
      [id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Rapport non trouvé' });
    }
    
    const analysis = result.rows[0].analysis;
    
    if (!analysis) {
      return res.status(202).json({ 
        message: 'Analyse en cours de génération',
        status: 'pending'
      });
    }
    
    res.json({ 
      success: true,
      analysis: typeof analysis === 'string' ? JSON.parse(analysis) : analysis
    });
  } catch (error) {
    console.error('❌ Erreur récupération analyse:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Route pour les rapports urgents du jour
router.get('/urgent/today', async (req, res) => {
  try {
    const urgentReports = await getUrgentReportsToday();
    
    res.json({
      success: true,
      count: urgentReports.length,
      reports: urgentReports.map(r => ({
        id: r.id,
        title: r.title,
        subject: r.subject,
        created_at: r.created_at,
        urgency: typeof r.analysis === 'string' 
          ? JSON.parse(r.analysis).signals.urgency 
          : r.analysis.signals.urgency,
        severity: typeof r.analysis === 'string'
          ? JSON.parse(r.analysis).signals.severity
          : r.analysis.signals.severity
      }))
    });
  } catch (error) {
    console.error('❌ Erreur rapports urgents:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Route pour les statistiques mensuelles
router.get('/statistics/monthly', async (req, res) => {
  try {
    const stats = await getMonthlyStatistics();
    
    if (!stats) {
      return res.status(500).json({ error: 'Impossible de générer les statistiques' });
    }
    
    res.json({
      success: true,
      month: new Date().toLocaleDateString('fr-FR', { year: 'numeric', month: 'long' }),
      statistics: stats
    });
  } catch (error) {
    console.error('❌ Erreur statistiques:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Route pour réanalyser un rapport
router.post('/:id/reanalyze', async (req, res) => {
  try {
    const { id } = req.params;
    
    // Vérifier que le rapport existe
    const reportResult = await pool.query(
      'SELECT * FROM employee_reports WHERE id = $1',
      [id]
    );
    
    if (reportResult.rows.length === 0) {
      return res.status(404).json({ error: 'Rapport non trouvé' });
    }
    
    const report = reportResult.rows[0];
    
    // Réinitialiser l'analyse
    await pool.query(
      'UPDATE employee_reports SET analysis = NULL WHERE id = $1',
      [id]
    );
    
    res.json({
      success: true,
      message: 'Réanalyse lancée en arrière-plan',
      report_id: id
    });
    
    // Lancer l'analyse en arrière-plan
    setImmediate(async () => {
      console.log(`\n🔄 === RÉANALYSE RAPPORT ${id} ===`);
      console.log(`📋 Titre: ${report.title}`);
      
      try {
        const analysis = await analyzeReportHybrid(
          report.content,
          report.title,
          report.subject
        );
        
        console.log('\n✅ === RÉANALYSE RÉUSSIE ===');
        console.log('⚠️  Gravité:', analysis.severity.level, `(${analysis.severity.score}/10)`);
        console.log('⏰ Urgence:', analysis.urgency.level, `(${analysis.urgency.score}/10)`);
        
        await pool.query(
          'UPDATE employee_reports SET analysis = $1, updated_at = NOW() WHERE id = $2',
          [JSON.stringify(analysis), id]
        );
        
        console.log('💾 Réanalyse sauvegardée');
        
      } catch (error) {
        console.error('\n❌ === ERREUR RÉANALYSE ===');
        console.error('Message:', error.message);
        
        const fallbackAnalysis = generateFallbackAnalysis(report.content);
        await pool.query(
          'UPDATE employee_reports SET analysis = $1, updated_at = NOW() WHERE id = $2',
          [JSON.stringify(fallbackAnalysis), id]
        );
        
        console.log('🛡️  Analyse de fallback sauvegardée');
      }
    });
    
  } catch (error) {
    console.error('❌ Erreur réanalyse:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Route pour rechercher des rapports par mots-clés
router.post('/search/keywords', async (req, res) => {
  try {
    const { keywords, language = 'ar' } = req.body;
    
    if (!keywords || !Array.isArray(keywords) || keywords.length === 0) {
      return res.status(400).json({ error: 'Mots-clés requis' });
    }
    
    const result = await pool.query(`
      SELECT id, title, subject, analysis, created_at
      FROM employee_reports
      WHERE analysis IS NOT NULL
      ORDER BY created_at DESC
      LIMIT 100
    `);
    
    // Filtrer par mots-clés dans l'analyse
    const matchingReports = result.rows.filter(report => {
      const analysis = typeof report.analysis === 'string'
        ? JSON.parse(report.analysis)
        : report.analysis;
      
      const reportKeywords = analysis.keywords || [];
      const reportCategories = analysis.categories || [];
      
      return keywords.some(keyword => 
        reportKeywords.some(k => k.toLowerCase().includes(keyword.toLowerCase())) ||
        reportCategories.some(c => c.toLowerCase().includes(keyword.toLowerCase()))
      );
    });
    
    res.json({
      success: true,
      count: matchingReports.length,
      reports: matchingReports.map(r => ({
        id: r.id,
        title: r.title,
        subject: r.subject,
        created_at: r.created_at,
        keywords: typeof r.analysis === 'string'
          ? JSON.parse(r.analysis).keywords
          : r.analysis.keywords,
        categories: typeof r.analysis === 'string'
          ? JSON.parse(r.analysis).categories
          : r.analysis.categories
      }))
    });
  } catch (error) {
    console.error('❌ Erreur recherche:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});



 // Statistiques de performance et délais
router.get('/statistics/performance', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        er.id,
        er.created_at,
        er.updated_at,
        er.status,
        er.analysis,
        EXTRACT(EPOCH FROM (er.updated_at - er.created_at))/3600 as hours_to_process,
        e.first_name,
        e.last_name
      FROM employee_reports er
      LEFT JOIN employees e ON e.id = er.employee_id
      WHERE er.created_at >= NOW() - INTERVAL '30 days'
      ORDER BY er.created_at DESC
    `);

    const stats = {
      total: result.rows.length,
      pending: result.rows.filter(r => r.status === 'pending').length,
      acknowledged: result.rows.filter(r => r.status === 'acknowledged').length,
      average_processing_hours: 0,
      overdue_24h: 0,
      overdue_48h: 0,
      overdue_7days: 0,
      fastest_response: null,
      slowest_response: null
    };

    const processingTimes = [];
    const now = new Date();

    result.rows.forEach(row => {
      if (row.status === 'acknowledged' && row.hours_to_process) {
        processingTimes.push(row.hours_to_process);
      }

      // Vérifier les retards
      if (row.status === 'pending') {
        const hoursOld = (now - new Date(row.created_at)) / (1000 * 60 * 60);
        if (hoursOld > 168) stats.overdue_7days++;  // 7 jours
        else if (hoursOld > 48) stats.overdue_48h++;
        else if (hoursOld > 24) stats.overdue_24h++;
      }
    });

    if (processingTimes.length > 0) {
      stats.average_processing_hours = (
        processingTimes.reduce((a, b) => a + b, 0) / processingTimes.length
      ).toFixed(2);
      stats.fastest_response = Math.min(...processingTimes).toFixed(2);
      stats.slowest_response = Math.max(...processingTimes).toFixed(2);
    }

    res.json({ success: true, statistics: stats });
  } catch (error) {
    console.error('Erreur statistiques performance:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});

// Analyse horaire des rapports
router.get('/statistics/hourly', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        EXTRACT(HOUR FROM created_at) as hour,
        COUNT(*) as count,
        AVG((analysis->>'urgency'->>'score')::float) as avg_urgency
      FROM employee_reports
      WHERE created_at >= NOW() - INTERVAL '30 days'
      AND analysis IS NOT NULL
      GROUP BY EXTRACT(HOUR FROM created_at)
      ORDER BY hour
    `);

    res.json({ success: true, hourly_distribution: result.rows });
  } catch (error) {
    console.error('Erreur statistiques horaires:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
});
// ========================================
// 📊 ROUTE STATISTIQUES AVANCÉES
// ========================================
router.get('/statistics/dashboard', async (req, res) => {
  try {
    const { period = 'month', department_id = null } = req.query;
    
    // Déterminer la période
    let dateFilter = '';
    switch(period) {
      case 'day':
        dateFilter = "DATE(created_at) = CURRENT_DATE";
        break;
      case 'week':
        dateFilter = "created_at >= DATE_TRUNC('week', CURRENT_DATE)";
        break;
      case 'month':
        dateFilter = "created_at >= DATE_TRUNC('month', CURRENT_DATE)";
        break;
      case 'year':
        dateFilter = "created_at >= DATE_TRUNC('year', CURRENT_DATE)";
        break;
      default:
        dateFilter = "1=1"; // Tous les rapports
    }

    // Requête principale pour les rapports de la période
    const reportsQuery = `
      SELECT 
        er.id,
        er.employee_id,
        er.title,
        er.created_at,
        er.analysis,
        e.first_name,
        e.last_name,
        ed.department_id
      FROM employee_reports er
      LEFT JOIN employees e ON e.id = er.employee_id
      LEFT JOIN employee_departments ed ON ed.employee_id = er.employee_id
      WHERE ${dateFilter.replace(/\bcreated_at\b/g, 'er.created_at')}
      AND er.analysis IS NOT NULL
      ${department_id ? 'AND ed.department_id = $1' : ''}
    `;

    const reportsResult = await pool.query(
      reportsQuery,
      department_id ? [department_id] : []
    );

    // Initialiser les statistiques
    const stats = {
      total_reports: reportsResult.rows.length,
      by_urgency: {
        critical: 0,      // 10
        very_high: 0,     // 8-9
        high: 0,          // 6-7
        medium: 0,        // 4-5
        low: 0            // 1-3
      },
      by_severity: {
        critical: 0,
        very_high: 0,
        high: 0,
        medium: 0,
        low: 0
      },
      by_sentiment: {
        positive: 0,
        negative: 0,
        neutral: 0
      },
      by_category: {},
      by_department: {},
      by_employee: {},
      daily_trend: {},
      top_keywords: {},
      response_time: {
        pending: 0,
        acknowledged: 0,
        average_hours: 0
      },
      critical_reports: []
    };

    // Traiter chaque rapport
    reportsResult.rows.forEach(row => {
      const analysis = typeof row.analysis === 'string' 
        ? JSON.parse(row.analysis) 
        : row.analysis;

      // Scores
      const urgencyScore = analysis.urgency?.score || 0;
      const severityScore = analysis.severity?.score || 0;

      // Classification par urgence
      if (urgencyScore >= 10) stats.by_urgency.critical++;
      else if (urgencyScore >= 8) stats.by_urgency.very_high++;
      else if (urgencyScore >= 6) stats.by_urgency.high++;
      else if (urgencyScore >= 4) stats.by_urgency.medium++;
      else stats.by_urgency.low++;

      // Classification par gravité
      if (severityScore >= 10) stats.by_severity.critical++;
      else if (severityScore >= 8) stats.by_severity.very_high++;
      else if (severityScore >= 6) stats.by_severity.high++;
      else if (severityScore >= 4) stats.by_severity.medium++;
      else stats.by_severity.low++;

      // Sentiment
      const sentiment = analysis.sentiment?.label;
      if (sentiment === 'إيجابي' || sentiment === 'positif') {
        stats.by_sentiment.positive++;
      } else if (sentiment === 'سلبي' || sentiment === 'négatif') {
        stats.by_sentiment.negative++;
      } else {
        stats.by_sentiment.neutral++;
      }

      // Catégories
      (analysis.categories || []).forEach(cat => {
        stats.by_category[cat] = (stats.by_category[cat] || 0) + 1;
      });

      // Mots-clés
      (analysis.keywords || []).forEach(keyword => {
        stats.top_keywords[keyword] = (stats.top_keywords[keyword] || 0) + 1;
      });

      // Par département
      if (row.department_id) {
        if (!stats.by_department[row.department_id]) {
          stats.by_department[row.department_id] = {
            total: 0,
            critical: 0,
            very_high: 0,
            high: 0,
            medium: 0,
            low: 0
          };
        }
        stats.by_department[row.department_id].total++;
        
        if (urgencyScore >= 10) stats.by_department[row.department_id].critical++;
        else if (urgencyScore >= 8) stats.by_department[row.department_id].very_high++;
        else if (urgencyScore >= 6) stats.by_department[row.department_id].high++;
        else if (urgencyScore >= 4) stats.by_department[row.department_id].medium++;
        else stats.by_department[row.department_id].low++;
      }

      // Par employé
      const employeeName = `${row.first_name} ${row.last_name}`;
      stats.by_employee[employeeName] = (stats.by_employee[employeeName] || 0) + 1;

      // Tendance journalière
      const day = new Date(row.created_at).toISOString().split('T')[0];
      if (!stats.daily_trend[day]) {
        stats.daily_trend[day] = { total: 0, critical: 0, high: 0, medium: 0, low: 0 };
      }
      stats.daily_trend[day].total++;
      
      if (urgencyScore >= 8) stats.daily_trend[day].critical++;
      else if (urgencyScore >= 6) stats.daily_trend[day].high++;
      else if (urgencyScore >= 4) stats.daily_trend[day].medium++;
      else stats.daily_trend[day].low++;

      // Rapports critiques
      if (urgencyScore >= 9 || severityScore >= 9) {
        stats.critical_reports.push({
          id: row.id,
          title: row.title,
          employee: employeeName,
          urgency: urgencyScore,
          severity: severityScore,
          created_at: row.created_at
        });
      }
    });

    // Trier et limiter
    stats.by_category = Object.entries(stats.by_category)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 15)
      .reduce((obj, [key, val]) => ({ ...obj, [key]: val }), {});

    stats.top_keywords = Object.entries(stats.top_keywords)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 20)
      .reduce((obj, [key, val]) => ({ ...obj, [key]: val }), {});

    stats.by_employee = Object.entries(stats.by_employee)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .reduce((obj, [key, val]) => ({ ...obj, [key]: val }), {});

    // Récupérer les noms des départements
    const departmentIds = Object.keys(stats.by_department);
    if (departmentIds.length > 0) {
      const deptResult = await pool.query(
        'SELECT id, name FROM departments WHERE id = ANY($1::uuid[])',
        [departmentIds]
      );
      
      const deptNames = {};
      deptResult.rows.forEach(d => {
        deptNames[d.id] = d.name;
      });

      const by_department_named = {};
      Object.entries(stats.by_department).forEach(([id, data]) => {
        by_department_named[deptNames[id] || 'Inconnu'] = data;
      });
      stats.by_department = by_department_named;
    }

    res.json({
      success: true,
      period,
      statistics: stats
    });

  } catch (error) {
    console.error('❌ Erreur statistiques dashboard:', error);
    res.status(500).json({ error: 'Erreur serveur', details: error.message });
  }
});

// ========================================
// 📡 ROUTES API SUPPLÉMENTAIRES
// ========================================


// 🔹 Récupérer tous les responsables avec leurs départements (VERSION AMÉLIORÉE)
router.get('/responsibles', async (req, res) => {
  try {
    console.log('🔍 Récupération des responsables...');
    
    const result = await pool.query(`
      SELECT 
        e.id,
        e.first_name,
        e.last_name,
        e.email,
        e.phone,
        d.name as department_name,
        d.id as department_id
      FROM employees e
      INNER JOIN departments d ON d.responsible_id = e.id
      ORDER BY d.name, e.first_name, e.last_name
    `);

    console.log(`✅ ${result.rows.length} responsables trouvés`);
    
    res.json({
      success: true,
      responsibles: result.rows
    });
    
  } catch (error) {
    console.error('❌ Erreur récupération responsables:', error);
    res.status(500).json({ 
      error: 'Impossible de récupérer les responsables',
      details: error.message 
    });
  }
});

// 🔹 Récupérer les départements d'un employé spécifique (pour debug)
router.get('/employee/:employeeId/departments', async (req, res) => {
  try {
    const { employeeId } = req.params;
    console.log(`🔍 Récupération des départements pour l'employé ${employeeId}...`);
    
    const result = await pool.query(`
      SELECT 
        d.id,
        d.name,
        d.responsible_id
      FROM employees emp
      INNER JOIN employee_departments ed ON ed.employee_id = emp.id
      INNER JOIN departments d ON d.id = ed.department_id
      WHERE emp.id = $1
    `, [employeeId]);

    console.log(`✅ ${result.rows.length} département(s) trouvé(s) pour l'employé ${employeeId}`);
    
    res.json({
      success: true,
      departments: result.rows
    });
    
  } catch (error) {
    console.error('❌ Erreur récupération départements par employé:', error);
    res.status(500).json({ 
      error: 'Impossible de récupérer les départements',
      details: error.message 
    });
  }
});

// 🔹 Récupérer le responsable du département d'un employé spécifique
router.get('/responsibles/by-employee/:employeeId', async (req, res) => {
  try {
    const { employeeId } = req.params;
    console.log(`🔍 [ROUTE MATCHED] GET /responsibles/by-employee/:employeeId - Employee ID: ${employeeId}`);
    
    // Requête corrigée utilisant la table employee_departments
    const result = await pool.query(`
      SELECT 
        resp.id,
        resp.first_name,
        resp.last_name,
        resp.email,
        resp.phone,
        d.name as department_name,
        d.id as department_id
      FROM employees emp
      INNER JOIN employee_departments ed ON ed.employee_id = emp.id
      INNER JOIN departments d ON d.id = ed.department_id
      INNER JOIN employees resp ON resp.id = d.responsible_id
      WHERE emp.id = $1
    `, [employeeId]);

    console.log(`✅ ${result.rows.length} responsable(s) trouvé(s) pour l'employé ${employeeId}`);
    
    res.json({
      success: true,
      responsibles: result.rows
    });
    
  } catch (error) {
    console.error('❌ Erreur récupération responsable par employé:', error);
    res.status(500).json({ 
      error: 'Impossible de récupérer le responsable',
      details: error.message 
    });
  }
});

// 🔹 Récupérer tous les employés qui peuvent être responsables (pour l'interface directeur)
router.get('/all-responsibles', async (req, res) => {
  try {
    console.log('🔍 Récupération de tous les employés responsables...');
    
    const result = await pool.query(`
      SELECT DISTINCT
        e.id,
        e.first_name,
        e.last_name,
        e.email,
        e.phone,
        d.name as department_name,
        d.id as department_id,
        CASE 
          WHEN EXISTS (SELECT 1 FROM departments d2 WHERE d2.responsible_id = e.id) THEN true
          ELSE false
        END as is_currently_responsible
      FROM employees e
      LEFT JOIN departments d ON d.responsible_id = e.id
      WHERE EXISTS (
        SELECT 1 FROM departments d2 WHERE d2.responsible_id = e.id
      )
      ORDER BY COALESCE(d.name, 'Sans département'), e.first_name, e.last_name
    `);

    console.log(`✅ ${result.rows.length} employés responsables trouvés`);
    
    res.json({
      success: true,
      responsibles: result.rows
    });
    
  } catch (error) {
    console.error('❌ Erreur récupération employés responsables:', error);
    res.status(500).json({ 
      error: 'Impossible de récupérer les employés responsables',
      details: error.message 
    });
  }
});

// 🔹 Route de test pour vérifier les responsables dans la base
router.get('/test-responsibles', async (req, res) => {
  try {
    console.log('🧪 Test des responsables...');
    
    // Vérifier tous les employés
    const allEmployees = await pool.query('SELECT id, first_name, last_name FROM employees ORDER BY first_name');
    console.log(`📊 Total employés: ${allEmployees.rows.length}`);
    
    // Vérifier tous les départements
    const allDepartments = await pool.query('SELECT id, name, responsible_id FROM departments ORDER BY name');
    console.log(`📊 Total départements: ${allDepartments.rows.length}`);
    
    // Vérifier les responsables
    const responsibles = await pool.query(`
      SELECT e.id, e.first_name, e.last_name, d.name as department_name
      FROM employees e
      INNER JOIN departments d ON d.responsible_id = e.id
      ORDER BY e.first_name
    `);
    console.log(`📊 Responsables trouvés: ${responsibles.rows.length}`);
    
    res.json({
      success: true,
      total_employees: allEmployees.rows.length,
      total_departments: allDepartments.rows.length,
      total_responsibles: responsibles.rows.length,
      employees: allEmployees.rows,
      departments: allDepartments.rows,
      responsibles: responsibles.rows
    });
    
  } catch (error) {
    console.error('❌ Erreur test responsables:', error);
    res.status(500).json({ 
      error: 'Erreur test responsables',
      details: error.message 
    });
  }
});

// 🔹 Récupérer le nom d'un responsable par son ID (VERSION AMÉLIORÉE)
router.get('/responsible/:id/name', async (req, res) => {
    try {
        const { id } = req.params;
        
        const result = await pool.query(`
            SELECT e.first_name, e.last_name, d.name as department_name
            FROM employees e
            LEFT JOIN departments d ON d.responsible_id = e.id
            WHERE e.id = $1
        `, [id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ 
                success: false,
                error: 'Responsable introuvable' 
            });
        }

        const responsible = result.rows[0];
        const name = `${responsible.first_name} ${responsible.last_name}`;
        const fullName = responsible.department_name 
          ? `${name} (${responsible.department_name})` 
          : name;

        res.json({
            success: true,
            name: fullName,
            short_name: name,
            department: responsible.department_name
        });
    } catch (error) {
        console.error('❌ Erreur récupération nom responsable:', error);
        res.status(500).json({ 
            success: false,
            error: 'Impossible de récupérer le nom du responsable' 
        });
    }
});

// 📊 Récupérer les rapports d'un employé (VERSION CORRIGÉE)
router.get('/employee/:employeeId/reports', async (req, res) => {
  try {
    let { employeeId } = req.params;
    const { status, period } = req.query;

    console.log('🔍 [ROUTE MATCHED] GET /employee/:employeeId/reports - Employee ID:', employeeId);
    console.log('📋 Filtres:', { status, period });

    // Resolve user_id to employee_id if needed (same fix as tasks endpoint)
    let actualEmployeeId = employeeId;
    
    // Check if it's an employee ID first
    let employeeCheck = await pool.query(
      'SELECT id FROM employees WHERE id = $1',
      [employeeId]
    );
    
    // If not found, try as user_id
    if (employeeCheck.rows.length === 0) {
      employeeCheck = await pool.query(
        'SELECT id FROM employees WHERE user_id = $1',
        [employeeId]
      );
      
      if (employeeCheck.rows.length > 0) {
        actualEmployeeId = employeeCheck.rows[0].id;
        console.log('✅ Resolved user_id to employee_id for reports:', employeeId, '->', actualEmployeeId);
      }
    }

    // Requête de base avec la NOUVELLE structure de table
    let query = `
      SELECT 
        id,
        employee_id,
        title,
        subject,
        content,
        concerned_employees,
        status,
        remarks,
        pdf_url,
        created_at,
        updated_at,
        recipients,
        include_director
      FROM employee_reports 
      WHERE employee_id = $1
    `;
    
    const params = [actualEmployeeId];
    let paramCount = 1;

    // Filtre par statut
    if (status && status !== 'all') {
      paramCount++;
      query += ` AND status = $${paramCount}`;
      params.push(status);
    }

    // Filtre par période
    if (period && period !== 'all') {
      const now = new Date();
      let startDate;
      
      switch (period) {
        case 'today':
          startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
          break;
        case 'week':
          startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
          break;
        case 'month':
          startDate = new Date(now.getFullYear(), now.getMonth(), 1);
          break;
        default:
          startDate = null;
      }
      
      if (startDate) {
        paramCount++;
        query += ` AND created_at >= $${paramCount}`;
        params.push(startDate.toISOString());
      }
    }

    query += ` ORDER BY created_at DESC`;

    console.log('📝 Requête SQL:', query);
    console.log('🔢 Paramètres:', params);

    const result = await pool.query(query, params);
    
    console.log(`✅ ${result.rows.length} rapports trouvés`);

    res.json({
      success: true,
      reports: result.rows
    });

  } catch (error) {
    console.error('❌ Erreur récupération rapports employé:', error);
    res.status(500).json({ 
      success: false,
      error: 'Impossible de récupérer les rapports',
      details: error.message,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
});
// 📊 Statistiques des rapports
router.get('/employee/:employeeId/stats', async (req, res) => {
  try {
    const { employeeId } = req.params;

    const result = await pool.query(`
  SELECT 
    COUNT(*) as total,
    COUNT(CASE WHEN status = 'acknowledged' THEN 1 END) as acknowledged,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending
  FROM employee_reports 
  WHERE employee_id = $1
`, [employeeId]);


    res.json({
      success: true,
      stats: result.rows[0]
    });
  } catch (error) {
    console.error('❌ Erreur statistiques rapports:', error);
    res.status(500).json({ error: 'Impossible de récupérer les statistiques' });
  }
});


// 🔹 Récupérer un employé par son user_id
router.get('/employees/by-user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    console.log('🔍 Récupération employé par user_id:', userId);

    const result = await pool.query(`
      SELECT 
        e.id,
        e.first_name,
        e.last_name,
        e.user_id,
        d.id as department_id,
        d.name as department_name
      FROM employees e
      LEFT JOIN employee_departments ed ON e.id = ed.employee_id
      LEFT JOIN departments d ON ed.department_id = d.id
      WHERE e.user_id = $1
      LIMIT 1
    `, [userId]);

    if (result.rows.length === 0) {
      return res.status(404).json({ 
        success: false, 
        error: 'Employee not found for given user_id' 
      });
    }

    res.json({ 
      success: true, 
      employee: result.rows[0] 
    });
  } catch (error) {
    console.error('❌ Erreur récupération employé par user_id:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Impossible de récupérer l\'employé',
      details: error.message 
    });
  }
});

// 📋 Récupérer les détails complets d'un employé avec son département
router.get('/employees/:id/details', async (req, res) => {
  try {
    const { id } = req.params;
    console.log('🔍 [ROUTE MATCHED] GET /employees/:id/details - Employee ID:', id);

    const result = await pool.query(`
      SELECT 
        e.*,
        d.name as department_name,
        d.id as department_id
      FROM employees e
      LEFT JOIN employee_departments ed ON e.id = ed.employee_id
      LEFT JOIN departments d ON ed.department_id = d.id
      WHERE e.id = $1
    `, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ 
        success: false,
        error: 'Employé introuvable' 
      });
    }

    res.json({
      success: true,
      employee: result.rows[0]
    });
  } catch (error) {
    console.error('❌ Erreur récupération détails employé:', error);
    res.status(500).json({ 
      success: false,
      error: 'Impossible de récupérer les détails' 
    });
  }
});
// 📊 Récupérer les rapports destinés à un responsable
router.get('/responsible/:responsibleId/reports', async (req, res) => {
  try {
    const { responsibleId } = req.params;
    const { status, period } = req.query;

    console.log('🔍 Chargement des rapports pour responsable:', responsibleId);

    // Requête pour récupérer les rapports où ce responsable est destinataire
    let query = `
      SELECT 
        er.id,
        er.employee_id,
        er.title,
        er.subject,
        er.content,
        er.concerned_employees,
        er.status,
        er.remarks,
        er.pdf_url,
        er.created_at,
        er.updated_at,
        er.recipients,
        er.include_director,
        e.first_name,
        e.last_name,
        CONCAT(e.first_name, ' ', e.last_name) as employee_name,
        COALESCE(d.name, d_resp.name) as department_name
      FROM employee_reports er
      JOIN employees e ON er.employee_id = e.id
      LEFT JOIN employee_departments ed ON e.id = ed.employee_id
      LEFT JOIN departments d ON ed.department_id = d.id
      LEFT JOIN departments d_resp ON d_resp.responsible_id = e.id
      WHERE (
        $1 = ANY(er.recipients)
      ) AND er.employee_id != $1
    `;
    
    const params = [responsibleId];
    let paramCount = 1;

    // Filtre par statut
    if (status && status !== 'all') {
      paramCount++;
      query += ` AND er.status = $${paramCount}`;
      params.push(status);
    }

    // Filtre par période
    if (period && period !== 'all') {
      const now = new Date();
      let startDate;
      
      switch (period) {
        case 'today':
          startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
          break;
        case 'week':
          startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
          break;
        case 'month':
          startDate = new Date(now.getFullYear(), now.getMonth(), 1);
          break;
        default:
          startDate = null;
      }
      
      if (startDate) {
        paramCount++;
        query += ` AND er.created_at >= $${paramCount}`;
        params.push(startDate.toISOString());
      }
    }

    query += ` ORDER BY er.created_at DESC`;

    console.log('📝 Requête SQL:', query);
    console.log('🔢 Paramètres:', params);

    const result = await pool.query(query, params);
    
    console.log(`✅ ${result.rows.length} rapports trouvés pour le responsable`);

    res.json({
      success: true,
      reports: result.rows
    });

  } catch (error) {
    console.error('❌ Erreur récupération rapports responsable:', error);
    res.status(500).json({ 
      success: false,
      error: 'Impossible de récupérer les rapports',
      details: error.message
    });
  }
});

// 📋 Accuser réception d'un rapport (VERSION CORRIGÉE)
router.put('/:id/acknowledge', async (req, res) => {
  try {
    const { id } = req.params;
    const { acknowledged_by } = req.body;

    console.log('🔄 Accusé de réception pour rapport:', id, 'par:', acknowledged_by);

    // Vérifier que le rapport existe
    const reportResult = await pool.query(
      'SELECT id, recipients, include_director FROM employee_reports WHERE id = $1',
      [id]
    );

    if (reportResult.rows.length === 0) {
      return res.status(404).json({ 
        success: false,
        error: 'Rapport introuvable' 
      });
    }

    const report = reportResult.rows[0];

    // Vérifier si l'utilisateur est un destinataire valide
    const isRecipient = report.recipients && report.recipients.includes(acknowledged_by);
    const isDirector = report.include_director;
    
    // Pour l'instant, nous allons autoriser tout utilisateur valide à accuser réception
    // (vous pourriez vouloir ajouter une vérification plus stricte plus tard)
    if (!isRecipient && !isDirector) {
      console.warn('⚠️ Utilisateur non destinataire tente d\'accuser réception:', acknowledged_by);
      // Note: Pour l'instant, nous autorisons quand même pour debugger
      // return res.status(403).json({ 
      //   success: false,
      //   error: 'Vous n\'êtes pas destinataire de ce rapport' 
      // });
    }

    // Enregistrer l'accusé de réception dans la table report_acknowledgements
    try {
      await pool.query(`
        INSERT INTO report_acknowledgements (report_id, employee_id, acknowledged, acknowledged_at)
        VALUES ($1, $2, true, NOW())
        ON CONFLICT (report_id, employee_id) 
        DO UPDATE SET acknowledged = true, acknowledged_at = NOW()
      `, [id, acknowledged_by]);
      
      console.log('✅ Accusé enregistré dans report_acknowledgements');
    } catch (dbError) {
      console.error('❌ Erreur insertion dans report_acknowledgements:', dbError);
      // Continuer malgré l'erreur pour ne pas bloquer le processus
    }

    // Vérifier si tous les destinataires ont accusé réception
    let allAcknowledged = false;
    
    if (report.recipients && report.recipients.length > 0) {
      const acknowledgementsResult = await pool.query(`
        SELECT COUNT(*) as total_recipients,
               COUNT(CASE WHEN ra.acknowledged = true THEN 1 END) as acknowledged_count
        FROM (
          SELECT unnest(recipients) as recipient_id 
          FROM employee_reports 
          WHERE id = $1
        ) r
        LEFT JOIN report_acknowledgements ra ON ra.employee_id = r.recipient_id AND ra.report_id = $1
      `, [id]);

      if (acknowledgementsResult.rows.length > 0) {
        const stats = acknowledgementsResult.rows[0];
        allAcknowledged = stats.acknowledged_count === stats.total_recipients;
        console.log(`📊 Statistiques accusés: ${stats.acknowledged_count}/${stats.total_recipients}`);
      }
    }

    // Mettre à jour le statut du rapport si tous ont accusé réception
    if (allAcknowledged) {
      await pool.query(`
        UPDATE employee_reports 
        SET status = 'acknowledged', updated_at = NOW()
        WHERE id = $1
      `, [id]);
      console.log('✅ Tous les destinataires ont accusé réception - Statut mis à jour');
    }

    res.json({
      success: true,
      message: 'Accusé de réception enregistré avec succès',
      all_acknowledged: allAcknowledged
    });

  } catch (error) {
    console.error('❌ Erreur accusé de réception:', error);
    res.status(500).json({ 
      success: false,
      error: 'Impossible d\'enregistrer l\'accusé de réception',
      details: error.message 
    });
  }
});
// 📊 Statistiques des rapports pour un responsable
router.get('/responsible/:responsibleId/stats', async (req, res) => {
  try {
    const { responsibleId } = req.params;

    const result = await pool.query(`
      SELECT 
        COUNT(*) as total,
        COUNT(CASE WHEN status = 'acknowledged' THEN 1 END) as acknowledged,
        COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending,
        COUNT(CASE WHEN DATE(created_at) = CURRENT_DATE THEN 1 END) as today
      FROM employee_reports 
      WHERE $1 = ANY(recipients)
    `, [responsibleId]);

    res.json({
      success: true,
      stats: result.rows[0]
    });
    
  } catch (error) {
    console.error('❌ Erreur statistiques responsable:', error);
    res.status(500).json({ 
      success: false,
      error: 'Impossible de récupérer les statistiques' 
    });
  }
});

// 📋 Marquer tous les rapports en attente comme accusés pour un responsable
router.put('/responsible/:responsibleId/acknowledge-all', async (req, res) => {
  try {
    const { responsibleId } = req.params;

    console.log('🔄 Accusé global pour responsable:', responsibleId);

    // Mettre à jour tous les rapports en attente
    const result = await pool.query(`
      UPDATE employee_reports 
      SET 
        status = 'acknowledged',
        updated_at = NOW()
      WHERE status = 'pending' 
        AND (
          $1 = ANY(recipients) OR 
          (include_director = true AND EXISTS(
            SELECT 1 FROM departments WHERE responsible_id = $1
          ))
        )
      RETURNING id, title
    `, [responsibleId]);

    const updatedCount = result.rows.length;

    console.log(`✅ ${updatedCount} rapports accusés en masse`);

    res.json({
      success: true,
      message: `${updatedCount} rapports accusés avec succès`,
      updated_reports: result.rows
    });

  } catch (error) {
    console.error('❌ Erreur accusé global:', error);
    res.status(500).json({ 
      success: false,
      error: 'Impossible d\'accuser tous les rapports',
      details: error.message 
    });
  }
});

// 📋 Récupérer les détails d'un rapport avec informations étendues pour responsable
router.get('/responsible/:responsibleId/report/:reportId', async (req, res) => {
  try {
    const { responsibleId, reportId } = req.params;

    const result = await pool.query(`
      SELECT 
        er.*,
        e.first_name,
        e.last_name,
        e.email as employee_email,
        COALESCE(d.name, d_resp.name) as department_name,
        CASE 
          WHEN er.concerned_employees IS NOT NULL 
          THEN (
            SELECT string_agg(CONCAT(ce.first_name, ' ', ce.last_name), ', ')
            FROM employees ce 
            WHERE ce.id = ANY(er.concerned_employees)
          )
          ELSE NULL
        END as concerned_employees_names
      FROM employee_reports er
      JOIN employees e ON er.employee_id = e.id
      LEFT JOIN employee_departments ed ON e.id = ed.employee_id
      LEFT JOIN departments d ON ed.department_id = d.id
      LEFT JOIN departments d_resp ON d_resp.responsible_id = e.id
      WHERE er.id = $1 
        AND $2 = ANY(er.recipients)
    `, [reportId, responsibleId]);

    if (result.rows.length === 0) {
      return res.status(404).json({ 
        success: false,
        error: 'Rapport introuvable ou accès non autorisé' 
      });
    }

    res.json({
      success: true,
      report: result.rows[0]
    });
    
  } catch (error) {
    console.error('❌ Erreur détails rapport responsable:', error);
    res.status(500).json({ 
      success: false,
      error: 'Impossible de récupérer les détails du rapport' 
    });
  }
});

// 📊 Récupérer les accusés de réception pour un rapport
// 📊 Récupérer les accusés de réception pour un rapport (VERSION AMÉLIORÉE)
router.get('/:id/acknowledgements', async (req, res) => {
  try {
    const { id } = req.params;
    
    // Vérifier d'abord si le rapport existe
    const reportCheck = await pool.query(
      'SELECT id, recipients, include_director FROM employee_reports WHERE id = $1',
      [id]
    );
    
    if (reportCheck.rows.length === 0) {
      return res.status(404).json({ 
        success: false,
        error: 'Rapport introuvable' 
      });
    }
    
    const report = reportCheck.rows[0];

    // Construire la liste finale des destinataires logiques (incluant le Directeur si applicable)
    let recipientIds = Array.isArray(report.recipients) ? [...report.recipients] : [];
    let directorEmployeeId = null;

    if (report.include_director) {
      // Récupérer tous les employés ayant le rôle Director
      const directorsRes = await pool.query(`
        SELECT e.id AS employee_id
        FROM users u
        INNER JOIN employees e ON e.user_id = u.id
        WHERE u.role = 'Director'
      `);
      const directorIds = directorsRes.rows.map(r => r.employee_id);

      if (directorIds.length > 0) {
        // Voir si l'un de ces directeurs a déjà accusé réception pour ce rapport
        const raRes = await pool.query(`
          SELECT employee_id, acknowledged, acknowledged_at
          FROM report_acknowledgements
          WHERE report_id = $1 AND employee_id = ANY($2::uuid[])
          ORDER BY acknowledged DESC, acknowledged_at DESC NULLS LAST
          LIMIT 1
        `, [id, directorIds]);

        if (raRes.rows.length > 0) {
          directorEmployeeId = raRes.rows[0].employee_id;
        } else {
          directorEmployeeId = directorIds[0];
        }

        if (directorEmployeeId && !recipientIds.includes(directorEmployeeId)) {
          recipientIds.unshift(directorEmployeeId);
        }
      }
    }

    if (recipientIds.length === 0) {
      return res.json({
        success: true,
        acknowledgements: [],
        total: 0,
        acknowledged: 0
      });
    }

    // Récupérer les infos d'accusé pour tous les destinataires (y compris le Directeur)
    const result = await pool.query(`
      SELECT 
        e.id, 
        e.first_name, 
        e.last_name,
        e.email,
        CASE WHEN u.role = 'Director' THEN 'Direction Générale' ELSE d.name END AS department_name,
        COALESCE(ra.acknowledged, false) AS acknowledged,
        ra.acknowledged_at
      FROM employees e
      LEFT JOIN users u ON u.id = e.user_id
      LEFT JOIN departments d ON d.responsible_id = e.id
      LEFT JOIN report_acknowledgements ra 
        ON ra.employee_id = e.id AND ra.report_id = $1
      WHERE e.id = ANY($2::uuid[])
      ORDER BY e.first_name, e.last_name
    `, [id, recipientIds]);

    // Forcer le libellé du directeur à "Direction Générale"
    const rows = result.rows.map(r => {
      if (r.department_name === 'Direction Générale') {
        return {
          ...r,
          first_name: 'Direction Générale',
          last_name: ''
        };
      }
      return r;
    });

    res.json({
      success: true,
      acknowledgements: rows,
      total: rows.length,
      acknowledged: rows.filter(r => r.acknowledged).length
    });

  } catch (error) {
    console.error('❌ Erreur récupération accusés:', error);
    res.status(500).json({ 
      success: false,
      error: 'Impossible de récupérer les accusés',
      details: error.message 
    });
  }
});

// 📋 Récupérer un rapport spécifique
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    console.log('🔍 Tentative de récupération du rapport:', id);

    const result = await pool.query(`
      SELECT 
        er.*,
        e.first_name,
        e.last_name,
        COALESCE(d.id, d2.id) as department_id,
        COALESCE(d.name, d2.name) as department_name
      FROM employee_reports er
      JOIN employees e ON er.employee_id = e.id
      LEFT JOIN employee_departments ed ON e.id = ed.employee_id
      LEFT JOIN departments d ON ed.department_id = d.id
      LEFT JOIN departments d2 ON d2.responsible_id = e.id
      WHERE er.id = $1
    `, [id]);

    if (result.rows.length === 0) {
      console.log('❌ Rapport non trouvé:', id);
      return res.status(404).json({ 
        success: false,
        error: 'Rapport introuvable' 
      });
    }

    console.log('✅ Rapport trouvé:', id);
    res.json({
      success: true,
      report: result.rows[0]
    });
  } catch (error) {
    console.error('❌ Erreur récupération rapport:', error);
    res.status(500).json({ 
      success: false,
      error: 'Impossible de récupérer le rapport',
      details: error.message 
    });
  }
});

// 📄 Générer PDF pour un rapport
router.get('/:id/pdf', async (req, res) => {
  try {
    const { id } = req.params;

    const result = await pool.query(`
      SELECT 
        er.*,
        e.first_name,
        e.last_name,
        COALESCE(d.id, d2.id) as department_id,
        COALESCE(d.name, d2.name) as department_name
      FROM employee_reports er
      JOIN employees e ON er.employee_id = e.id
      LEFT JOIN employee_departments ed ON e.id = ed.employee_id
      LEFT JOIN departments d ON ed.department_id = d.id
      LEFT JOIN departments d2 ON d2.responsible_id = e.id
      WHERE er.id = $1
    `, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Rapport introuvable' });
    }

    const report = result.rows[0];

    // Detect Arabic content (title, subject, content)
    const rawTitle = report.title || '';
    const rawSubject = report.subject || '';
    const rawContent = report.content || '';
    const isArabic = /[\u0600-\u06FF]/.test(`${rawTitle} ${rawSubject} ${rawContent}`);

    // Helpers for RTL text handling
    const rtlWrap = (txt) => {
      if (!txt) return '';
      let shaped = txt;
      // Try advanced shaping first
      try {
        const hasArabic = /[\u0600-\u06FF]/.test(shaped);
        if (hasArabic && arabicShaper) {
          // Apply glyph shaping
          shaped = arabicShaper.reshape ? arabicShaper.reshape(shaped) : arabicShaper(shaped);
        }
        if (hasArabic && bidiProcessor && bidiProcessor.getEmbeddingLevels) {
          // Reorder using bidi algorithm if available
          // Simple approach: reverse graphemes if levels indicate RTL span
          // Use unicode bidi isolates instead for safety
          shaped = `\u2067${shaped}\u2069`; // RLI...PDI
        }
      } catch (_) {}
      // If plugin is present, return shaped as-is; otherwise add RLE/PDF marks to improve bidi
      if (enablePdfRtl) return shaped;
      // Surround Arabic text with RLE (U+202B) ... PDF (U+202C)
      return `\u202B${shaped}\u202C`;
    };
    const writeText = (text, opts = {}) => {
      const content = isArabic ? rtlWrap(text) : text;
      const baseOpts = Object.assign({}, opts);
      if (enablePdfRtl && isArabic) {
        baseOpts.rtl = true;
      }
      doc.text(content, baseOpts);
    };

    // If Arabic: prefer HTML → PDF rendering via Puppeteer for perfect RTL shaping
    if (isArabic) {
      try {
        const puppeteer = require('puppeteer');
        const htmlSafe = (s) => (s || '').toString()
          .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
          .replace(/\"/g, '&quot;').replace(/\'/g, '&#39;');
        const schoolName = 'مدرسة الفضيلة الخاصة';
        const dept = report.department_name || 'غير محدد';
        const mainTitle = rawTitle || 'تقرير نشاط';
        const subj = rawSubject ? `الموضوع: ${htmlSafe(rawSubject)}` : '';
        // Force Arabic date to Western digits (e.g., 01/10/2025)
        const d = new Date(report.created_at);
        const pad2 = (n) => (n < 10 ? '0' + n : '' + n);
        const dateStr = `${pad2(d.getDate())}/${pad2(d.getMonth() + 1)}/${d.getFullYear()}`;
        const remarks = report.remarks ? htmlSafe(report.remarks) : '';
        const contentHtml = htmlSafe(rawContent).replace(/\n/g, '<br/>');

        const html = `<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8" />
  <meta http-equiv="X-UA-Compatible" content="IE=edge" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    body { font-family: 'Tahoma', 'Traditional Arabic', 'Noto Naskh Arabic', 'Noto Sans Arabic', sans-serif; direction: rtl; margin: 24px; color: #111827; }
    .header { text-align: center; }
    .title { font-size: 22px; font-weight: 700; text-decoration: underline; margin-top: 8px; }
    .subtitle { font-size: 15px; margin-top: 4px; }
    .section-title { font-size: 16px; font-weight: 700; margin-top: 18px; margin-bottom: 6px; }
    .meta { font-size: 12px; line-height: 1.7; margin-top: 12px; }
    .divider { height: 1px; background: #e5e7eb; margin: 12px 0; }
    .content { font-size: 13px; line-height: 1.9; text-align: right; }
    .footer { font-size: 10px; color: #6b7280; text-align: center; margin-top: 24px; }
    .label { color: #374151; }
  </style>
  <title>تقرير</title>
  <meta charset="utf-8" />
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
  <meta http-equiv="Content-Language" content="ar" />
</head>
<body>
  <div class="header">
    <div class="title">${schoolName}</div>
    <div class="subtitle"><span class="label">القسم:</span> ${htmlSafe(dept)}</div>
  </div>
  <div class="section-title">${htmlSafe(mainTitle)}</div>
  ${subj ? `<div class="subtitle">${subj}</div>` : ''}
  <div class="meta">
    <div><span class="label">تاريخ التحرير:</span> ${htmlSafe(dateStr)}</div>
    <div><span class="label">المحرِّر:</span> ${htmlSafe(report.first_name)} ${htmlSafe(report.last_name)}</div>
    ${remarks ? `<div>${remarks.replace('Destinataire', 'المستلم')}</div>` : ''}
  </div>
  <div class="divider"></div>
  <div class="section-title">المحتوى:</div>
  <div class="content">${contentHtml}</div>
  <div class="footer">
    تم توليد التقرير في: ${new Date().toLocaleString('fr-FR')}<br/>
    معرّف التقرير: ${htmlSafe(report.id)}
  </div>
</body>
</html>`;

        const browser = await puppeteer.launch({ headless: 'new', args: ['--no-sandbox', '--font-render-hinting=none'] });
        const page = await browser.newPage();
        await page.setContent(html, { waitUntil: 'load' });
        const buffer = await page.pdf({ format: 'A4', printBackground: true, margin: { top: '20mm', bottom: '15mm', left: '15mm', right: '15mm' } });
        await browser.close();
        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', `inline; filename=rapport-${id}.pdf`);
        return res.end(buffer);
      } catch (e) {
        console.warn('Arabic HTML→PDF fallback failed, using PDFKit. Error:', e.message);
      }
    }

    // Prepare PDF document (default and French template, or Arabic fallback)
    const doc = new PDFDocument({ margin: 50 });
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `inline; filename=rapport-${id}.pdf`);
    doc.pipe(res);

    // Register and select fonts (Arabic-capable fallback)
    // Try environment-provided font first, then common Windows fonts, then default
    let arabicFontPath = process.env.ARABIC_FONT_PATH || '';
    const candidateArabicFonts = [
      arabicFontPath,
      'C:\\Windows\\Fonts\\Tahoma.ttf', // Tahoma supports Arabic on Windows
      'C:\\Windows\\Fonts\\arabtype.ttf', // Arabic Typesetting
      'C:\\Windows\\Fonts\\trado.ttf', // Traditional Arabic
      '/usr/share/fonts/truetype/noto/NotoNaskhArabic-Regular.ttf',
      '/usr/share/fonts/truetype/noto/NotoSansArabic-Regular.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
    ].filter(Boolean);

    let selectedArabicFont = null;
    for (const p of candidateArabicFonts) {
      try {
        if (p && fs.existsSync(p)) {
          selectedArabicFont = p;
          break;
        }
      } catch (_) {}
    }

    try {
      if (selectedArabicFont) {
        doc.registerFont('Arabic', selectedArabicFont);
      }
    } catch (_) {}

    // Two distinct templates: Arabic and French
    const dateRedaction = new Date(report.created_at).toLocaleDateString("fr-FR", {
      day: "numeric", month: "long", year: "numeric"
    });

    if (isArabic) {
      // ===== Arabic Template =====
      if (selectedArabicFont) doc.font('Arabic'); else doc.font('Helvetica');
      doc.fontSize(20);
      const schoolName = "مدرسة الفضيلة الخاصة";
      writeText(schoolName, { align: "center", underline: true });
      doc.moveDown(0.5);
      if (selectedArabicFont) doc.font('Arabic'); else doc.font('Helvetica');
      doc.fontSize(14);
      writeText(`القسم: ${report.department_name || 'غير محدد'}`, { align: "center" });
      doc.moveDown(1.5);

      // Title and Subject
      if (selectedArabicFont) doc.font('Arabic'); else doc.font('Helvetica');
      const mainTitle = rawTitle || 'تقرير نشاط';
      doc.fontSize(18);
      writeText(mainTitle, { align: 'right' });
      doc.moveDown(0.5);
      if (rawSubject) {
        doc.fontSize(13);
      writeText(`الموضوع: ${rawSubject}`, { align: 'right' });
        doc.moveDown(1);
      }

      // Metadata
      doc.fontSize(12);
      // Force Western digits for date in Arabic fallback too
      const d2 = new Date(report.created_at);
      const pad2b = (n) => (n < 10 ? '0' + n : '' + n);
      const dateStrAr = `${pad2b(d2.getDate())}/${pad2b(d2.getMonth() + 1)}/${d2.getFullYear()}`;
      writeText(`تاريخ التحرير: ${dateStrAr}`, { align: 'right' });
      writeText(`المحرِّر: ${report.first_name} ${report.last_name}`, { align: 'right' });
      if (report.remarks) writeText(report.remarks.replace('Destinataire', 'المستلم'), { align: 'right' });

      // Separator
      doc.moveDown(1);
      doc.moveTo(50, doc.y).lineTo(doc.page.width - 50, doc.y).strokeColor('#dddddd').stroke();
      doc.moveDown(1);

      // Content section
      doc.fontSize(14);
      writeText('المحتوى:', { align: 'right' });
      doc.moveDown(0.3);
      if (selectedArabicFont) doc.font('Arabic'); else doc.font('Helvetica');
      doc.fontSize(12);
      writeText(rawContent, { align: 'right', lineGap: 5 });

      // Footer
      doc.moveDown(2);
      doc.fontSize(10).fillColor("#555555");
      if (selectedArabicFont) doc.font('Arabic'); else doc.font('Helvetica');
      writeText(`تم توليد التقرير في: ${new Date().toLocaleString("fr-FR")}`, { align: "center" });
      writeText(`معرّف التقرير: ${report.id}`, { align: "center" });
    } else {
      // ===== French Template =====
      doc.font('Helvetica-Bold');
      doc.fontSize(20);
      doc.text("École Privée El Fadila", { align: "center", underline: true });
      doc.moveDown(0.5);
      doc.font('Helvetica');
      doc.fontSize(14);
      doc.text(`Département: ${report.department_name || 'Non spécifié'}`, { align: "center" });
      doc.moveDown(1.5);

      // Title and Subject
      doc.font('Helvetica-Bold');
      const mainTitleFr = rawTitle || "RAPPORT D'ACTIVITÉ";
      doc.fontSize(18).text(mainTitleFr, { align: 'center' });
      doc.moveDown(0.5);
      if (rawSubject) {
        doc.font('Helvetica');
        doc.fontSize(13).text(`Objet: ${rawSubject}`, { align: 'center' });
        doc.moveDown(1);
      }

      // Metadata
      doc.font('Helvetica');
      doc.fontSize(12).text(`Date de rédaction : ${dateRedaction}`);
      doc.text(`Rédigé par : ${report.first_name} ${report.last_name}`);
      doc.text(`${report.remarks || 'Destinataire non spécifié'}`);

      // Separator
      doc.moveDown(1);
      doc.moveTo(50, doc.y).lineTo(doc.page.width - 50, doc.y).strokeColor('#dddddd').stroke();
      doc.moveDown(1);

      // Content section
      doc.font('Helvetica-Bold');
      doc.fontSize(14).text("Contenu du rapport:");
      doc.moveDown(0.3);
      doc.font('Helvetica');
      doc.fontSize(12).text(rawContent, { align: 'justify', lineGap: 5 });

      // Footer
      doc.moveDown(2);
      doc.fontSize(10).fillColor("#555555").font('Helvetica');
      doc.text(`Rapport généré le : ${new Date().toLocaleString("fr-FR")}`, { align: "center" });
      doc.text(`ID du rapport : ${report.id}`, { align: "center" });
    }

    doc.end();
  } catch (error) {
    console.error("❌ Erreur génération PDF:", error);
    res.status(500).json({ error: "Impossible de générer le PDF" });
  }
});

// 🏢 Interface Directeur - Récupérer tous les rapports avec filtres
router.get('/director/all-reports', async (req, res) => {
  try {
    const { 
      type, // 'employee' ou 'responsible'
      department_id, 
      employee_id, 
      responsible_id, 
      status, 
      period 
    } = req.query;

    console.log('🔍 Interface Directeur - Filtres:', { type, department_id, employee_id, responsible_id, status, period });

    let query = `
      SELECT 
        er.id,
        er.employee_id,
        er.title,
        er.subject,
        er.content,
        er.concerned_employees,
        er.status,
        er.remarks,
        er.pdf_url,
        er.analysis,
        er.created_at,
        er.updated_at,
        er.recipients,
        er.include_director,
        e.first_name,
        e.last_name,
        CONCAT(e.first_name, ' ', e.last_name) as employee_name,
        COALESCE(d.name, d2.name) as department_name,
        COALESCE(d.id, d2.id) as department_id,
        CASE 
          WHEN er.concerned_employees IS NOT NULL 
          THEN (
            SELECT string_agg(CONCAT(ce.first_name, ' ', ce.last_name), ', ')
            FROM employees ce 
            WHERE ce.id = ANY(er.concerned_employees)
          )
          ELSE NULL
        END as concerned_employees_names,
        'employee' as report_type
      FROM employee_reports er
      JOIN employees e ON er.employee_id = e.id
      LEFT JOIN employee_departments ed ON e.id = ed.employee_id
      LEFT JOIN departments d ON ed.department_id = d.id
      LEFT JOIN departments d2 ON d2.responsible_id = e.id
      WHERE 1=1
    `;
    
    const params = [];
    let paramCount = 0;

    // Filtre par type (employee ou responsible)
    if (type === 'employee') {
      // Rapports générés par des employés (non-responsables)
      query += ` AND NOT EXISTS (
        SELECT 1 FROM departments d2 WHERE d2.responsible_id = e.id
      )`;
    } else if (type === 'responsible') {
      // Rapports générés par des responsables
      query += ` AND EXISTS (
        SELECT 1 FROM departments d2 WHERE d2.responsible_id = e.id
      )`;
    }

    // Filtre par département
    if (department_id && department_id !== 'all') {
      paramCount++;
      query += ` AND d.id = $${paramCount}`;
      params.push(department_id);
    }

    // Filtre par employé spécifique
    if (employee_id && employee_id !== 'all') {
      paramCount++;
      query += ` AND er.employee_id = $${paramCount}`;
      params.push(employee_id);
    }

    // Filtre par responsable spécifique
    if (responsible_id && responsible_id !== 'all') {
      paramCount++;
      query += ` AND er.employee_id = $${paramCount}`;
      params.push(responsible_id);
    }

    // Filtre par statut
    if (status && status !== 'all') {
      paramCount++;
      query += ` AND er.status = $${paramCount}`;
      params.push(status);
    }

    // Filtre par période
    if (period && period !== 'all') {
      const now = new Date();
      let startDate;
      
      switch (period) {
        case 'today':
          startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
          break;
        case 'week':
          startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
          break;
        case 'month':
          startDate = new Date(now.getFullYear(), now.getMonth(), 1);
          break;
        default:
          startDate = null;
      }
      
      if (startDate) {
        paramCount++;
        query += ` AND er.created_at >= $${paramCount}`;
        params.push(startDate.toISOString());
      }
    }

    query += ` ORDER BY er.created_at DESC`;

    console.log('📝 Requête SQL Directeur:', query);
    console.log('🔢 Paramètres:', params);

    const result = await pool.query(query, params);
    
    console.log(`✅ ${result.rows.length} rapports trouvés pour le directeur`);

    res.json({
      success: true,
      reports: result.rows
    });

  } catch (error) {
    console.error('❌ Erreur récupération rapports directeur:', error);
    res.status(500).json({ 
      success: false,
      error: 'Impossible de récupérer les rapports',
      details: error.message 
    });
  }
});

// 🏢 Interface Directeur - Récupérer les départements
router.get('/director/departments', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        d.id,
        d.name,
        COUNT(DISTINCT e.id) as employee_count,
        COUNT(DISTINCT CASE WHEN d.responsible_id = e.id THEN e.id END) as responsible_count
      FROM departments d
      LEFT JOIN employee_departments ed ON d.id = ed.department_id
      LEFT JOIN employees e ON ed.employee_id = e.id
      GROUP BY d.id, d.name
      ORDER BY d.name
    `);

    res.json({
      success: true,
      departments: result.rows
    });
  } catch (error) {
    console.error('❌ Erreur récupération départements:', error);
    res.status(500).json({ 
      success: false,
      error: 'Impossible de récupérer les départements' 
    });
  }
});

// 🏢 Interface Directeur - Récupérer les employés par département
router.get('/director/employees-by-department/:departmentId', async (req, res) => {
  try {
    const { departmentId } = req.params;
    const { type } = req.query; // 'employee' ou 'responsible'

    if (type === 'responsible') {
      // Pour les responsables, récupérer directement depuis la table departments
      const query = `
        SELECT 
          e.id,
          e.first_name,
          e.last_name,
          e.email,
          d.name as department_name,
          'responsible' as employee_type
        FROM departments d
        JOIN employees e ON d.responsible_id = e.id
        WHERE d.id = $1
      `;

      const result = await pool.query(query, [departmentId]);

      res.json({
        success: true,
        employees: result.rows
      });
    } else {
      // Pour les employés, utiliser la table employee_departments
      const query = `
        SELECT 
          e.id,
          e.first_name,
          e.last_name,
          e.email,
          d.name as department_name,
          'employee' as employee_type
        FROM employees e
        JOIN employee_departments ed ON e.id = ed.employee_id
        JOIN departments d ON ed.department_id = d.id
        WHERE d.id = $1
          AND NOT EXISTS(SELECT 1 FROM departments d2 WHERE d2.responsible_id = e.id)
        ORDER BY e.first_name, e.last_name
      `;

      const result = await pool.query(query, [departmentId]);

      res.json({
        success: true,
        employees: result.rows
      });
    }
  } catch (error) {
    console.error('❌ Erreur récupération employés par département:', error);
    res.status(500).json({ 
      success: false,
      error: 'Impossible de récupérer les employés' 
    });
  }
});

// 🏢 Interface Directeur - Statistiques globales
router.get('/director/stats', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        COUNT(*) as total_reports,
        COUNT(CASE WHEN status = 'acknowledged' THEN 1 END) as acknowledged,
        COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending,
        COUNT(CASE WHEN DATE(created_at) = CURRENT_DATE THEN 1 END) as today,
        COUNT(CASE WHEN DATE(created_at) >= CURRENT_DATE - INTERVAL '7 days' THEN 1 END) as this_week,
        COUNT(CASE WHEN DATE(created_at) >= DATE_TRUNC('month', CURRENT_DATE) THEN 1 END) as this_month
      FROM employee_reports
    `);

    res.json({
      success: true,
      stats: result.rows[0]
    });
  } catch (error) {
    console.error('❌ Erreur statistiques directeur:', error);
    res.status(500).json({ 
      success: false,
      error: 'Impossible de récupérer les statistiques' 
    });
  }
});

// 🧭 Interface Directeur - Vue priorités (rapports analysés et groupés par gravité)
router.get('/director/priorities', async (req, res) => {
  try {
    const { limit = 300 } = req.query;

    // Charger les rapports avec métadonnées employé/département
    const result = await pool.query(`
      SELECT 
        er.id,
        er.employee_id,
        er.title,
        er.subject,
        er.content,
        er.pdf_url,
        er.status,
        er.created_at,
        er.updated_at,
        er.analysis,
        e.first_name,
        e.last_name,
        COALESCE(d.name, d2.name) as department_name
      FROM employee_reports er
      JOIN employees e ON er.employee_id = e.id
      LEFT JOIN employee_departments ed ON e.id = ed.employee_id
      LEFT JOIN departments d ON ed.department_id = d.id
      LEFT JOIN departments d2 ON d2.responsible_id = e.id
      WHERE er.analysis IS NOT NULL
      ORDER BY er.created_at DESC
      LIMIT $1
    `, [Math.max(1, Math.min(1000, Number(limit) || 300))]);

    const parseAnalysis = (a) => {
      try { return typeof a === 'string' ? JSON.parse(a) : a; } catch { return null; }
    };

    const normalize = (row) => {
      const analysis = parseAnalysis(row.analysis) || {};
      const severityScore = Number(analysis?.severity?.score ?? analysis?.signals?.severity_score ?? 0) || 0;
      const urgencyScore = Number(analysis?.urgency?.score ?? analysis?.signals?.urgency_score ?? 0) || 0;
      const severityLevel = analysis?.severity?.level || analysis?.signals?.severity || 'غير محدد';
      const urgencyLevel = analysis?.urgency?.level || analysis?.signals?.urgency || 'غير محدد';
      const bucket = severityScore >= 9 ? 'critical'
        : severityScore >= 7 ? 'very_urgent'
        : severityScore >= 4 ? 'moderate'
        : severityScore >= 1 ? 'low'
        : 'unknown';
      return {
        id: row.id,
        title: row.title,
        subject: row.subject,
        pdf_url: row.pdf_url,
        employee_name: `${row.first_name} ${row.last_name}`,
        department_name: row.department_name,
        status: row.status,
        created_at: row.created_at,
        severity: { score: severityScore, level: severityLevel },
        urgency: { score: urgencyScore, level: urgencyLevel },
        summary: analysis?.summary || null,
        keywords: Array.isArray(analysis?.keywords) ? analysis.keywords : [],
        entities: analysis?.entities || { persons: [], locations: [], organizations: [], dates: [] },
        categories: Array.isArray(analysis?.categories) ? analysis.categories : [],
        bucket
      };
    };

    const items = result.rows.map(normalize);

    const groups = {
      critical: items.filter(r => r.bucket === 'critical'),
      very_urgent: items.filter(r => r.bucket === 'very_urgent'),
      moderate: items.filter(r => r.bucket === 'moderate'),
      low: items.filter(r => r.bucket === 'low'),
      unknown: items.filter(r => r.bucket === 'unknown')
    };

    const kpi = {
      critical: groups.critical.length,
      very_urgent: groups.very_urgent.length,
      moderate: groups.moderate.length,
      low: groups.low.length
    };

    // Tendance simple: comparer 7 derniers jours vs 7 jours précédents
    const now = new Date();
    const start7 = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const start14 = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000);
    const countIn = (arr, start, end) => arr.filter(r => {
      const d = new Date(r.created_at);
      return d >= start && d < end;
    }).length;
    const trend = {
      critical: {
        current: countIn(groups.critical, start7, now),
        previous: countIn(groups.critical, start14, start7)
      },
      very_urgent: {
        current: countIn(groups.very_urgent, start7, now),
        previous: countIn(groups.very_urgent, start14, start7)
      },
      moderate: {
        current: countIn(groups.moderate, start7, now),
        previous: countIn(groups.moderate, start14, start7)
      },
      low: {
        current: countIn(groups.low, start7, now),
        previous: countIn(groups.low, start14, start7)
      }
    };

    res.json({ success: true, kpi, trend, groups, total: items.length });
  } catch (error) {
    console.error('❌ Erreur vue priorités:', error);
    res.status(500).json({ success: false, error: 'Impossible de charger la vue priorités' });
  }
});

// 🏢 Interface Directeur - Accuser réception d'un rapport
router.put('/director/:reportId/acknowledge', async (req, res) => {
  try {
    const { reportId } = req.params;
    const { director_id } = req.body;

    console.log('🔄 Directeur accuse réception:', reportId, 'par directeur:', director_id);

    // Vérifier que le rapport existe
    const reportResult = await pool.query(
      'SELECT id, recipients, include_director FROM employee_reports WHERE id = $1',
      [reportId]
    );

    if (reportResult.rows.length === 0) {
      console.log('❌ Rapport introuvable:', reportId);
      return res.status(404).json({ 
        success: false,
        error: 'Rapport introuvable' 
      });
    }

    console.log('✅ Rapport trouvé:', reportResult.rows[0]);

    // Vérifier que le directeur_id est valide
    if (!director_id) {
      console.log('❌ director_id manquant');
      return res.status(400).json({ 
        success: false,
        error: 'ID du directeur manquant' 
      });
    }

    // Vérifier que le directeur_id est un UUID valide
    const isUuid = (value) => typeof value === 'string' && /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$/.test(value);
    if (!isUuid(director_id)) {
      console.log('❌ director_id invalide:', director_id);
      return res.status(400).json({ 
        success: false,
        error: 'ID du directeur invalide' 
      });
    }

  // Vérifier que le directeur existe et a le bon rôle
  // Le director_id peut être soit l'ID utilisateur (users.id), soit l'ID employé (employees.id)
  let directorEmployeeId;
  let directorName;

  // Tentative 1: considérer director_id comme users.id
  const directorCheckByUser = await pool.query(`
      SELECT 
        e.id as employee_id,
        e.first_name,
        e.last_name,
        u.id as user_id,
        u.username,
        u.role
      FROM users u
      INNER JOIN employees e ON e.user_id = u.id
      WHERE u.id = $1 AND u.role = 'Director'
    `, [director_id]);

  if (directorCheckByUser.rows.length > 0) {
    directorEmployeeId = directorCheckByUser.rows[0].employee_id;
    directorName = `${directorCheckByUser.rows[0].first_name} ${directorCheckByUser.rows[0].last_name}`;
  } else {
    // Tentative 2: considérer director_id comme employees.id et vérifier que l'utilisateur lié est Directeur
    const directorCheckByEmployee = await pool.query(`
        SELECT 
          e.id as employee_id,
          e.first_name,
          e.last_name,
          u.id as user_id,
          u.username,
          u.role
        FROM employees e
        INNER JOIN users u ON u.id = e.user_id
        WHERE e.id = $1 AND u.role = 'Director'
      `, [director_id]);

    if (directorCheckByEmployee.rows.length > 0) {
      directorEmployeeId = directorCheckByEmployee.rows[0].employee_id;
      directorName = `${directorCheckByEmployee.rows[0].first_name} ${directorCheckByEmployee.rows[0].last_name}`;
    } else {
      // Échec des deux méthodes: retourner une erreur claire
      return res.status(403).json({
        success: false,
        error: 'Directeur introuvable ou rôle incorrect pour l\'ID fourni'
      });
    }
  }
    console.log('✅ Directeur trouvé:', directorName, 'ID employé:', directorEmployeeId);

    // Enregistrer l'accusé de réception du directeur
    console.log('💾 Insertion accusé de réception...');
    console.log('📋 Paramètres:', { reportId, directorEmployeeId, directorName });
    
    try {
      const acknowledgeResult = await pool.query(`
        INSERT INTO report_acknowledgements (report_id, employee_id, acknowledged, acknowledged_at)
        VALUES ($1, $2, true, NOW())
        ON CONFLICT (report_id, employee_id) 
        DO UPDATE SET acknowledged = true, acknowledged_at = NOW()
        RETURNING id, acknowledged, acknowledged_at
      `, [reportId, directorEmployeeId]);
      
      console.log('✅ Accusé de réception enregistré:', acknowledgeResult.rows[0]);
    } catch (dbError) {
      console.error('❌ Erreur lors de l\'insertion dans report_acknowledgements:', dbError);
      console.error('❌ Détails de l\'erreur:', {
        code: dbError.code,
        detail: dbError.detail,
        constraint: dbError.constraint,
        message: dbError.message
      });
      
      return res.status(500).json({ 
        success: false,
        error: 'Erreur lors de l\'enregistrement de l\'accusé de réception',
        details: dbError.message,
        debug_info: {
          report_id: reportId,
          employee_id: directorEmployeeId,
          director_name: directorName
        }
      });
    }

    // Vérifier si tous les destinataires ont accusé réception
    const report = reportResult.rows[0];
    let allAcknowledged = false;

    // Cas directeur seul (aucun destinataire explicite): marquer directement comme acknowledged
    if (!report.recipients || report.recipients.length === 0) {
      await pool.query(`
        UPDATE employee_reports 
        SET status = 'acknowledged', updated_at = NOW()
        WHERE id = $1
      `, [reportId]);
      allAcknowledged = true;
    } else {
      const acknowledgementsResult = await pool.query(`
        SELECT COUNT(*) as total_recipients,
               COUNT(CASE WHEN ra.acknowledged = true THEN 1 END) as acknowledged_count
        FROM (
          SELECT unnest(recipients) as recipient_id 
          FROM employee_reports 
          WHERE id = $1
        ) r
        LEFT JOIN report_acknowledgements ra ON ra.employee_id = r.recipient_id AND ra.report_id = $1
      `, [reportId]);

      if (acknowledgementsResult.rows.length > 0) {
        const stats = acknowledgementsResult.rows[0];
        allAcknowledged = stats.acknowledged_count === stats.total_recipients;
      }
    }

    // Mettre à jour le statut du rapport si tous ont accusé réception
    if (allAcknowledged) {
      await pool.query(`
        UPDATE employee_reports 
        SET status = 'acknowledged', updated_at = NOW()
        WHERE id = $1
      `, [reportId]);
    }

    res.json({
      success: true,
      message: 'Accusé de réception enregistré avec succès',
      all_acknowledged: allAcknowledged
    });

  } catch (error) {
    console.error('❌ Erreur accusé de réception directeur:', error);
    console.error('❌ Stack trace:', error.stack);
    res.status(500).json({ 
      success: false,
      error: 'Impossible d\'enregistrer l\'accusé de réception',
      details: error.message,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
});

module.exports = router;
 
// 🔎 Recherche sémantique (fallback JSONB, sans pgvector)
router.post('/search-similar', async (req, res) => {
  try {
    const { text, limit = 10, window = 500 } = req.body || {};
    if (!text || typeof text !== 'string') {
      return res.status(400).json({ success: false, error: 'Paramètre text requis' });
    }

    // Embedding de la requête
    const feat = await hf.featureExtraction({
      model: 'sentence-transformers/all-MiniLM-L6-v2',
      inputs: text
    });
    const toVector = (out) => Array.isArray(out[0]) ? (function() {
      const dims = out[0].length;
      const acc = new Array(dims).fill(0);
      for (const row of out) { for (let d=0; d<dims; d++) acc[d] += row[d]; }
      for (let d=0; d<dims; d++) acc[d] /= out.length; return acc;
    })() : out;
    const q = toVector(feat);

    // Charger un sous-ensemble récent avec embeddings JSONB
    const { rows } = await pool.query(`
      SELECT id, title, subject, content, analysis_embedding_json
      FROM employee_reports
      WHERE analysis_embedding_json IS NOT NULL
      ORDER BY created_at DESC
      LIMIT $1
    `, [Math.max(1, Math.min(5000, window))]);

    const dot = (a, b) => {
      let s = 0; const n = Math.min(a.length, b.length);
      for (let i=0;i<n;i++) s += (a[i]||0) * (b[i]||0);
      return s;
    };
    const norm = (a) => Math.sqrt(dot(a,a)) || 1;

    const qn = norm(q);
    const scored = rows
      .map(r => {
        let v;
        try { v = Array.isArray(r.analysis_embedding_json) ? r.analysis_embedding_json : JSON.parse(r.analysis_embedding_json); } catch (_) { v = null; }
        if (!Array.isArray(v) || v.length === 0) return null;
        const s = dot(q, v) / (qn * norm(v));
        return { id: r.id, title: r.title, subject: r.subject, score: s };
      })
      .filter(Boolean)
      .sort((a,b) => b.score - a.score)
      .slice(0, Math.max(1, Math.min(100, limit)));

    res.json({ success: true, results: scored });
  } catch (error) {
    console.error('❌ Erreur recherche similaire:', error);
    res.status(500).json({ success: false, error: 'Recherche similaire impossible', details: error.message });
  }
});