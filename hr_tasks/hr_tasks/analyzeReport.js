const express = require("express");
const dotenv = require("dotenv");
const { Pool } = require("pg");
const { HfInference } = require("@huggingface/inference");

dotenv.config();

// Connexion PostgreSQL
const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
});

// Hugging Face API
const hf = new HfInference(process.env.HF_ACCESS_TOKEN);

const app = express();
app.use(express.json());

app.post("/reports/:id/analyze", async (req, res) => {
  const { id } = req.params;

  try {
    const { rows } = await pool.query(
      "SELECT title, subject, content FROM employee_reports WHERE id=$1",
      [id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: "Report not found" });
    }

    const { title, subject, content } = rows[0];
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
    const text = dedupeSentences(`${title}\n${subject}\n${content}`);
    const extractiveSummary = (txt) => {
      const sentences = txt.split(/[\.!?\n]+/).map(s => s.trim()).filter(Boolean);
      if (sentences.length <= 2) return sentences.join('. ') + (sentences.length ? '.' : '');
      const stopwords = new Set([
        'le','la','les','un','une','des','de','du','au','aux','et','ou','a','à','est','sont','je','tu','il','elle','nous','vous','ils','elles','en','dans','sur','par','pour','avec','sans','ne','pas','que','qui','quoi','quand','où','comment','why','the','a','an','and','or','in','on','at','to','of','for','is','are','was','were','be','been','this','that','these','those','i','you','he','she','we','they','it','from','as','by','about','into','over','after','before','between','during','your','their','our'
      ]);
      const words = txt
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

    const summaryText = extractiveSummary(text);

    const sentiment = await hf.textClassification({
      model: "cardiffnlp/twitter-xlm-roberta-base-sentiment",
      inputs: text,
    });

    // Normalisation des résultats HF
    const topSentiment = Array.isArray(sentiment) ? sentiment[0] : sentiment;
    const rawLabel = (topSentiment?.label || '').toUpperCase();
    let sentimentFr = 'neutre';
    if (rawLabel.includes('POSITIVE') || rawLabel.includes('POS')) sentimentFr = 'positif';
    else if (rawLabel.includes('NEGATIVE') || rawLabel.includes('NEG')) sentimentFr = 'négatif';
    const score = topSentiment?.score ?? null;
    if (score !== null && score < 0.7) sentimentFr = 'neutre';

    // Mots-clés simples
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
    const keywords = [...freq.entries()]
      .sort((a,b) => b[1]-a[1])
      .slice(0, 8)
      .map(([w]) => w)
      .filter((w, i, arr) => arr.indexOf(w) === i);

    const analysis = {
      summary: summaryText,
      sentiment: {
        label: sentimentFr,
        score
      },
      keywords
    };


    await pool.query(
      "UPDATE employee_reports SET analysis=$1, updated_at=now() WHERE id=$2",
      [JSON.stringify(analysis), id]
    );

    res.json({ success: true, analysis });
} catch (err) {
    console.error("Erreur analyse report:", err); // 🔥 log détaillé
    res.status(500).json({ error: "Internal server error", details: err.message });
  }
  
});

app.listen(process.env.TASK_SERVICE_PORT, () => {
  console.log(`Server running on port ${process.env.TASK_SERVICE_PORT}`);
});
