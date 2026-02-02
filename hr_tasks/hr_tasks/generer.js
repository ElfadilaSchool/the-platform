const { v4: uuidv4 } = require('uuid');
const PDFDocument = require('pdfkit');
const express = require('express');
const router = express.Router();
const pool = require('./db');

// 📋 Get all reports
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        r.*,
        t.title as task_title,
        t.description as task_description,
        e.first_name,
        e.last_name,
        e.email,
        d.name as department_name
      FROM reports r
      LEFT JOIN tasks t ON r.task_id = t.id
      LEFT JOIN employees e ON r.employee_id = e.id
      LEFT JOIN employee_departments ed ON e.id = ed.employee_id
      LEFT JOIN departments d ON ed.department_id = d.id
      ORDER BY r.created_at DESC
    `);
    
    res.json(result.rows);
  } catch (error) {
    console.error('❌ Error fetching reports:', error);
    res.status(500).json({ error: 'Failed to fetch reports' });
  }
});

// ➕ Ajouter un rapport
router.post('/', async (req, res) => {
  try {
    console.log("📩 Données reçues:", req.body);
    const { task_id, employee_id, description, remarks } = req.body;

    if (!task_id || !employee_id || !description) {
      return res.status(400).json({ error: 'Champs requis manquants' });
    }

    const newId = uuidv4();
    console.log("🆔 Nouvel ID généré:", newId);
    
    const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT || 3004}`;
    const pdfUrl = `${baseUrl}/api/reports/${newId}/pdf`;

    const result = await pool.query(
      `INSERT INTO reports (id, task_id, employee_id, description, remarks, created_at, pdf_url)
       VALUES ($1, $2, $3, $4, $5, NOW(), $6)
       RETURNING *`,
      [newId, task_id, employee_id, description, remarks || null, pdfUrl]
    );

    console.log("✅ Rapport créé avec succès:", {
      id: result.rows[0].id,
      pdf_url: result.rows[0].pdf_url
    });

    res.status(201).json({
      success: true,
      report: result.rows[0],
      message: 'Rapport ajouté avec succès'
    });
  } catch (error) {
    console.error('❌ Erreur ajout rapport:', error);
    res.status(500).json({ error: 'Impossible d ajouter le rapport' });
  }
});

// 📄 Récupérer un rapport spécifique (pour vérifier l'existence)
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    console.log("🔍 Recherche rapport avec ID:", id, "Type:", typeof id);

    // Vérifier que l'ID est bien un UUID valide
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(id)) {
      console.log("❌ ID invalide (pas un UUID):", id);
      return res.status(400).json({ error: 'ID de rapport invalide' });
    }

    const result = await pool.query(`
      SELECT r.*, t.title, e.first_name, e.last_name
      FROM reports r
      JOIN tasks t ON r.task_id = t.id
      JOIN employees e ON r.employee_id = e.id
      WHERE r.id = $1
    `, [id]);

    console.log("🔍 Résultats de la requête:", result.rows.length, "lignes trouvées");

    if (result.rows.length === 0) {
      // Vérifier si le rapport existe vraiment dans la base
      const checkResult = await pool.query('SELECT id FROM reports WHERE id = $1', [id]);
      console.log("🔍 Vérification existence dans reports:", checkResult.rows.length);
      
      return res.status(404).json({ error: 'Rapport introuvable' });
    }

    console.log("✅ Rapport trouvé:", result.rows[0].id);
    res.json({ success: true, report: result.rows[0] });
  } catch (error) {
    console.error('❌ Erreur récupération rapport:', error);
    res.status(500).json({ error: 'Impossible de récupérer le rapport' });
  }
});

// 📄 Générer un PDF pour un rapport
router.get('/:id/pdf', async (req, res) => {
  try {
    const { id } = req.params;
    console.log("📄 Génération PDF pour rapport ID:", id);

    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(id)) {
      return res.status(400).json({ error: 'ID de rapport invalide' });
    }

    const result = await pool.query(`
      SELECT r.*, t.title, t.due_date, e.first_name, e.last_name,
             eb.first_name as assigned_by_first_name, eb.last_name as assigned_by_last_name
      FROM reports r
      JOIN tasks t ON r.task_id = t.id
      JOIN employees e ON r.employee_id = e.id
      LEFT JOIN employees eb ON t.assigned_by = eb.id
      WHERE r.id = $1
    `, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Rapport introuvable' });
    }

    const report = result.rows[0];

    const doc = new PDFDocument({ margin: 50 });
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `inline; filename=rapport-${id}.pdf`);
    doc.pipe(res);

    // ===== En-tête =====
    doc.fontSize(18).text("École Privée El Fadila", { align: "center", underline: true });
    doc.moveDown(0.5);
    doc.fontSize(12).text("Nom de l'Unité/Département : ____________________", { align: "center" });
    doc.moveDown(2);

    // ===== Titre principal =====
    doc.fontSize(16).text("COMPTE-RENDU / RAPPORT D'ACTIVITÉ", { align: "center", bold: true });
    doc.moveDown(2);

    // ===== Métadonnées =====
    const dateRedaction = new Date(report.created_at).toLocaleDateString("fr-FR", {
      day: "numeric", month: "long", year: "numeric"
    });

    doc.fontSize(12).text(`Date de rédaction : ${dateRedaction}`);
    doc.text(`Rédigé par : ${report.first_name} ${report.last_name} (Employé)`);
    doc.text(`Destinataire(s) : Responsable (${report.assigned_by_first_name} ${report.assigned_by_last_name}) et Directeur/Directrice`);
    doc.moveDown(2);

    // ===== Section 1 : Informations de la tâche =====
    doc.fontSize(14).text("1. INFORMATIONS DE LA TÂCHE", { underline: true });
    doc.moveDown(0.5);
    doc.fontSize(12).text(`Titre : ${report.title}`);
    if (report.due_date) {
      doc.text(`Date d'échéance : ${new Date(report.due_date).toLocaleDateString("fr-FR")}`);
    }
    doc.moveDown(1.5);

    // ===== Section 2 : Compte-rendu détaillé =====
    doc.fontSize(14).text("2. COMPTE-RENDU DÉTAILLÉ", { underline: true });
    doc.moveDown(0.5);
    doc.fontSize(12).text(report.description || "Aucun compte-rendu fourni.", {
      align: "justify"
    });
    doc.moveDown(1.5);

    // ===== Section 3 : Remarques importantes =====
    doc.fontSize(14).text("3. REMARQUES IMPORTANTES", { underline: true });
    doc.moveDown(0.5);
    doc.fontSize(12).text(report.remarks || "Aucune remarque.", {
      align: "justify"
    });
    doc.moveDown(2);

    // ===== Pied de page =====
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


// 📋 Récupérer tous les rapports d'une tâche
router.get('/task/:taskId', async (req, res) => {
  try {
    const { taskId } = req.params;
    console.log("📋 Récupération rapports pour tâche:", taskId);

    const result = await pool.query(`
      SELECT r.id, r.description, r.remarks, r.created_at, r.pdf_url,
             e.first_name, e.last_name
      FROM reports r
      JOIN employees e ON r.employee_id = e.id
      WHERE r.task_id = $1
      ORDER BY r.created_at DESC
    `, [taskId]);

    console.log(`📋 ${result.rows.length} rapports trouvés pour la tâche ${taskId}`);
    
    // Afficher les IDs trouvés pour débogage
    result.rows.forEach(report => {
      console.log(`  - Rapport ID: ${report.id} par ${report.first_name} ${report.last_name}`);
    });

    res.json({ success: true, reports: result.rows });
  } catch (error) {
    console.error("❌ Erreur récupération rapports:", error);
    res.status(500).json({ error: "Impossible de récupérer les rapports" });
  }
});

// 🔍 Endpoint de débogage pour lister tous les rapports
router.get('/debug/all', async (req, res) => {
  try {
    const result = await pool.query('SELECT id, task_id, employee_id, created_at FROM reports ORDER BY created_at DESC LIMIT 10');
    console.log("🔍 DEBUG - Tous les rapports:", result.rows);
    res.json({ success: true, reports: result.rows });
  } catch (error) {
    console.error("❌ Erreur debug:", error);
    res.status(500).json({ error: "Erreur debug" });
  }
});

module.exports = router;