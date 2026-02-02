const express = require('express');
const { v4: uuidv4 } = require('uuid');
const PDFDocument = require('pdfkit');
const router = express.Router();
const pool = require('./db');
const dotenv = require('dotenv');
const { HfInference } = require('@huggingface/inference');

dotenv.config();
const hf = new HfInference(process.env.HF_ACCESS_TOKEN);

// 📝 Créer un nouveau rapport (version corrigée)
// VERSION FINALE DE LA ROUTE /create - Remplacer complètement votre route existante

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

    const finalContent = `${content}\n\nCordialement,`;

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
    const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 3004}`;
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

    // Répondre immédiatement: laisse le frontend fermer le formulaire sans attendre l'analyse
    res.status(201).json({
      success: true,
      report: newReport,
      message: 'Rapport créé. Analyse en arrière-plan.'
    });

    // 🔹 Analyse en arrière-plan (ne bloque pas la réponse HTTP)
    setImmediate(async () => {
      try {
        // Helpers: normalisation & extraction
      const removeDiacritics = (s) => s.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
      const normalizeWhitespace = (s) => s.replace(/\s+/g, ' ').trim();
      const normalizeText = (s) => normalizeWhitespace(removeDiacritics(s.toLowerCase()));
      const dedupeSentences = (s) => {
        const seen = new Set();
        const sentences = s
          .split(/[\.!?\n]+/)
          .map(t => normalizeWhitespace(t))
          .filter(Boolean);
        const unique = [];
        for (const sent of sentences) {
          const key = normalizeText(sent);
          if (!seen.has(key)) {
            seen.add(key);
            unique.push(sent);
          }
        }
        return unique.join('. ') + (unique.length ? '.' : '');
      };
      const extractiveSummary = (text) => {
        const sentences = text.split(/[\.!?\n]+/).map(s => s.trim()).filter(Boolean);
        if (sentences.length <= 2) return sentences.join('. ') + (sentences.length ? '.' : '');
        const stopwords = new Set([
          'le','la','les','un','une','des','de','du','au','aux','et','ou','a','à','est','sont','je','tu','il','elle','nous','vous','ils','elles','en','dans','sur','par','pour','avec','sans','ne','pas','que','qui','quoi','quand','où','comment','why','the','a','an','and','or','in','on','at','to','of','for','is','are','was','were','be','been','this','that','these','those','i','you','he','she','we','they','it','from','as','by','about','into','over','after','before','between','during','your','their','our'
        ]);
        const words = text
          .toLowerCase()
          .normalize('NFD')
          .replace(/[\u0300-\u036f]/g, '')
          .replace(/[^\p{L}\p{N}\s-]/gu, ' ')
          .split(/\s+/)
          .filter(w => w && w.length > 2 && !stopwords.has(w));
        const freq = new Map();
        for (const w of words) freq.set(w, (freq.get(w) || 0) + 1);
        const scoreSentence = (s) => {
          const tokens = s
            .toLowerCase()
            .normalize('NFD')
            .replace(/[\u0300-\u036f]/g, '')
            .replace(/[^\p{L}\p{N}\s-]/gu, ' ')
            .split(/\s+/)
            .filter(w => w && w.length > 2 && !stopwords.has(w));
          let score = 0;
          for (const t of tokens) score += (freq.get(t) || 0);
          return score / Math.max(tokens.length, 1);
        };
        const ranked = sentences
          .map((s, idx) => ({ s, idx, score: scoreSentence(s) }))
          .sort((a,b) => b.score - a.score)
          .slice(0, 2)
          .sort((a,b) => a.idx - b.idx)
          .map(x => x.s);
        return ranked.join('. ') + (ranked.length ? '.' : '');
      };

      const rawText = `${newReport.title}\n${newReport.subject}\n${newReport.content}`;
      const cleanedText = dedupeSentences(rawText);
      const summaryText = extractiveSummary(cleanedText);

      // Multilingual sentiment
      const sentiment = await hf.textClassification({
        model: 'cardiffnlp/twitter-xlm-roberta-base-sentiment',
        inputs: cleanedText
      });

      const topSentiment = Array.isArray(sentiment) ? sentiment[0] : sentiment;
      const rawLabel = (topSentiment?.label || '').toUpperCase();
      let sentimentFr = 'neutre';
      if (rawLabel.includes('POSITIVE') || rawLabel.includes('POS')) sentimentFr = 'positif';
      else if (rawLabel.includes('NEGATIVE') || rawLabel.includes('NEG')) sentimentFr = 'négatif';

      // Neutral band tweak: if score < 0.7, mark neutral
      const score = topSentiment?.score ?? null;
      if (score !== null && score < 0.7) sentimentFr = 'neutre';

      // Extraction de mots-clés améliorée (unigrammes + bigrammes, fr + en)
      const stopwords = new Set([
        'le','la','les','un','une','des','de','du','au','aux','et','ou','a','à','est','sont','été','etre','je','tu','il','elle','nous','vous','ils','elles','en','dans','sur','par','pour','avec','sans','ne','pas','que','qui','quoi','quand','où','comment','dont','duquel','auquel','auxquels','auxquelles','the','a','an','and','or','in','on','at','to','of','for','is','are','was','were','be','been','this','that','these','those','i','you','he','she','we','they','it','from','as','by','about','into','over','after','before','between','during','your','their','our','immediately','immediate','immédiatement','ont','aux','auxquels','auxquelles'
      ]);
      const originalTokens = cleanedText
        .replace(/[^\p{L}\p{N}\s-]/gu, ' ')
        .split(/\s+/)
        .filter(Boolean);
      const normalizedTokens = originalTokens.map(t => t
        .toLowerCase()
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, ''));
      const unigramFreq = new Map();
      const displayMap = new Map(); // normalized -> first seen original (avec accents)
      for (let i = 0; i < normalizedTokens.length; i++) {
        const n = normalizedTokens[i];
        const o = originalTokens[i];
        if (!n || n.length <= 2 || stopwords.has(n) || /^(\d+|\d{1,2}h\d{2})$/.test(n)) continue;
        displayMap.set(n, displayMap.get(n) || o);
        unigramFreq.set(n, (unigramFreq.get(n) || 0) + 1);
      }
      const bigramFreq = new Map();
      const bigramDisplay = new Map();
      for (let i = 0; i < normalizedTokens.length - 1; i++) {
        const n1 = normalizedTokens[i];
        const n2 = normalizedTokens[i+1];
        const o1 = originalTokens[i];
        const o2 = originalTokens[i+1];
        // éviter bigrammes qui commencent/finissent par stopword
        if (!n1 || !n2 || stopwords.has(n1) || stopwords.has(n2) || n1.length <= 2 || n2.length <= 2) continue;
        const key = `${n1} ${n2}`;
        bigramDisplay.set(key, bigramDisplay.get(key) || `${o1} ${o2}`);
        bigramFreq.set(key, (bigramFreq.get(key) || 0) + 1);
      }
      const topUnigrams = [...unigramFreq.entries()].sort((a,b) => b[1]-a[1]).slice(0, 8).map(([n]) => displayMap.get(n));
      const topBigrams = [...bigramFreq.entries()].sort((a,b) => b[1]-a[1]).slice(0, 5).map(([k]) => bigramDisplay.get(k));
      // filtrer bigrammes faibles (début/fin par prépositions fréquentes)
      const weakEdges = /^(de|du|des|d'|à|au|aux|dans|sur|par|pour|avec|sans|en|et|ou)\b|\b(de|du|des|d'|à|au|aux|dans|sur|par|pour|avec|sans|en|et|ou)$/i;
      const cleanedBigrams = topBigrams.filter(bg => !weakEdges.test(bg));
      const keywords = [...new Set([...cleanedBigrams, ...topUnigrams])];

      // Extraction générique d'entités (date, heure, lieu, actions, impacts)
      const entities = {};
      // Date: fusionner motifs jour+numéro+mois+année même sans ponctuation
      const dayNames = new Set(['lundi','mardi','mercredi','jeudi','vendredi','samedi','dimanche','lun','mar','mer','jeu','ven','sam','dim']);
      const monthNames = new Set(['janvier','fevrier','février','mars','avril','mai','juin','juillet','aout','août','septembre','octobre','novembre','decembre','décembre','janv','févr','avr','juil','août','sept','oct','nov','déc']);
      for (let i = 0; i < normalizedTokens.length; i++) {
        const n = normalizedTokens[i];
        const o = originalTokens[i];
        if (dayNames.has(n) && i+1 < normalizedTokens.length) {
          const n1 = normalizedTokens[i+1];
          if (/^(\d{1,2}|1er)$/i.test(n1)) {
            const parts = [originalTokens[i], originalTokens[i+1]];
            if (i+2 < normalizedTokens.length && monthNames.has(normalizedTokens[i+2])) parts.push(originalTokens[i+2]);
            if (i+3 < normalizedTokens.length && /^\d{4}$/.test(normalizedTokens[i+3])) parts.push(originalTokens[i+3]);
            entities.date = parts.join(' ');
            break;
          }
        }
        if (/^\d{4}-\d{2}-\d{2}$/.test(n)) { entities.date = o; break; }
      }
      // Heure simple (HHhMM ou HH:MM)
      for (let i = 0; i < normalizedTokens.length; i++) {
        const o = originalTokens[i];
        if (/^\d{1,2}h\d{2}$/i.test(o) || /^\d{1,2}:\d{2}$/.test(o)) { entities.time = o; break; }
      }
      // Lieux: capturer tête sémantique et étendre quelques tokens (sans dépendre de la ponctuation)
      const locationHeads = new Set(['bâtiment','batiment','salle','laboratoire','classe','cour','gymnase','bibliothèque','cafétéria','cafeteria','cantine','parking','bureau']);
      const locs = [];
      for (let i = 0; i < normalizedTokens.length; i++) {
        const n = normalizedTokens[i];
        if (locationHeads.has(n)) {
          const start = Math.max(0, i-1);
          const end = Math.min(originalTokens.length, i+5);
          const span = originalTokens.slice(start, end).join(' ');
          locs.push(span);
        }
      }
      if (locs.length > 0) entities.locations = [...new Set(locs)].slice(0, 3);
      // Actions effectuées / à faire
      const actionKeywords = new Set(['évacuation','evacuation','évacués','évacues','évacuer','alerter','alertés','pompiers','police','secours','vérifier','sensibiliser','réparer','isoler','interrompre','annuler','reporter','contacter','appliquer']);
      const actions = originalTokens.filter((o, idx) => actionKeywords.has(normalizedTokens[idx]));
      if (actions.length > 0) entities.actions = [...new Set(actions)].slice(0, 8);
      // Recommandations: capturer expression après déclencheurs
      const recTriggers = [/^recommand[eé]e?\b/i, /^conseill[eé]\b/i, /^il\s+est\s+recommand[eé]\s+de\b/i, /^il\s+est\s+conseill[eé]\s+de\b/i];
      const recs = [];
      for (let i = 0; i < originalTokens.length; i++) {
        const windowTokens = originalTokens.slice(i, i+6).join(' ');
        if (recTriggers.some(r => r.test(windowTokens))) {
          const snippet = originalTokens.slice(i, Math.min(originalTokens.length, i+16)).join(' ');
          recs.push(snippet);
        }
      }
      if (recs.length > 0) entities.recommendations = [...new Set(recs)].slice(0, 3);
      // Personnes (éléve Nom Prénom)
      const persons = [];
      for (let i = 0; i < originalTokens.length-2; i++) {
        if (normalizedTokens[i] === 'élève' || normalizedTokens[i] === 'eleve') {
          const n1 = originalTokens[i+1];
          const n2 = originalTokens[i+2];
          if (/^[A-ZÉÈÀÂÎÔÛÇ][\p{L}-]+$/u.test(n1) && /^[A-ZÉÈÀÂÎÔÛÇ][\p{L}-]+$/u.test(n2)) {
            persons.push(`${n1} ${n2}`);
          }
        }
      }
      if (persons.length > 0) entities.persons = [...new Set(persons)];
      // Parties du corps
      const bodyParts = new Set(['poignet','cheville','tête','bras','jambe','épaule','dos','main','pied','cou','genou']);
      const parts = originalTokens.filter((o, idx) => bodyParts.has(normalizedTokens[idx]));
      if (parts.length > 0) entities.body_parts = [...new Set(parts)];
      // Victimes
      const victimsNone = /(aucune?\s+victime|pas\s+de\s+victime)/i.test(cleanedText);
      if (victimsNone) entities.victims = 'aucune';

      // Heuristiques de sévérité/urgence génériques
      const severeTerms = ['incendie','accident','agression','fuite','explosion','menace','urgence','fracture','hôpital','hopital','perte','connaissance'];
      const urgentTerms = ['immédiatement','immediatement','urgent','urgence','évacuation','evacuation','pompiers','secours','premiers','soins','infirmière','infirmiere'];
      const normText = normalizedTokens.join(' ');
      const severityCount = severeTerms.reduce((c, t) => c + (normText.includes(t) ? 1 : 0), 0);
      const urgencyCount = urgentTerms.reduce((c, t) => c + (normText.includes(t) ? 1 : 0), 0);
      const severity = severityCount >= 2 ? 'élevée' : (severityCount === 1 ? 'moyenne' : 'faible');
      const urgency = urgencyCount >= 2 ? 'élevée' : (urgencyCount === 1 ? 'moyenne' : 'faible');

      const analysis = {
        summary: summaryText,
        sentiment: {
          label: sentimentFr,
          score
        },
        keywords,
        entities,
        signals: { severity, urgency }
      };

      // 🔹 Update seulement la colonne analysis
      await pool.query(
        'UPDATE employee_reports SET analysis=$1, updated_at=now() WHERE id=$2',
        [JSON.stringify(analysis), newReport.id]
      );
      } catch (err) {
        console.error('Erreur analyse (arrière-plan):', err);
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
    console.log(`🔍 Récupération du responsable pour l'employé ${employeeId}...`);
    
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

          WHEN EXISTS(SELECT 1 FROM departments d2 WHERE d2.responsible_id = e.id) 
          THEN true 
          ELSE false         SELECT DISTINCT
        e.id,
        e.first_name,
        e.last_name,
        e.email,
        e.phone,
        d.name as department_name,
        d.id as department_id,
        CASE 
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
    const { employeeId } = req.params;
    const { status, period } = req.query;

    console.log('🔍 Chargement des rapports pour employé:', employeeId);
    console.log('📋 Filtres:', { status, period });

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
    
    const params = [employeeId];
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


// 📋 Récupérer les détails complets d'un employé avec son département
router.get('/employees/:id/details', async (req, res) => {
  try {
    const { id } = req.params;
    console.log('🔍 Récupération détails employé:', id);

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
    const doc = new PDFDocument({ margin: 50 });
    
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `inline; filename=rapport-${id}.pdf`);
    doc.pipe(res);

    // En-tête avec logo
    doc.fontSize(20).text("École Privée El Fadila", { align: "center", underline: true });
    doc.moveDown(0.5);
    doc.fontSize(14).text(`Département: ${report.department_name || 'Non spécifié'}`, { align: "center" });
    doc.moveDown(2);

    // Titre principal
    doc.fontSize(18).text("RAPPORT D'ACTIVITÉ", { align: "center", bold: true });
    doc.moveDown(2);

    // Métadonnées
    const dateRedaction = new Date(report.created_at).toLocaleDateString("fr-FR", {
      day: "numeric", month: "long", year: "numeric"
    });

    doc.fontSize(12).text(`Date de rédaction : ${dateRedaction}`);
    doc.text(`Rédigé par : ${report.first_name} ${report.last_name}`);
    doc.text(`Département : ${report.department_name || 'Non spécifié'}`);
    doc.text(`${report.remarks || 'Destinataire non spécifié'}`);
    doc.moveDown(2);

    // Contenu du rapport
    doc.fontSize(12).text(report.content, {
      align: "justify",
      lineGap: 5
    });

    // Pied de page
    doc.moveDown(3);
    doc.fontSize(10).fillColor("#555555")
      .text(`Rapport généré le : ${new Date().toLocaleString("fr-FR")}`, { align: "center" })
      .text(`ID du rapport : ${report.id}`, { align: "center" });

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