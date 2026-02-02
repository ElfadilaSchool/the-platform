const dotenv = require("dotenv");
const { HfInference } = require("@huggingface/inference");

dotenv.config();

const hf = new HfInference(process.env.HF_ACCESS_TOKEN);

async function test() {
  const text = "Ceci est un petit test de résumé et d'analyse de sentiment.";

  try {
    const summary = await hf.summarization({
      model: "facebook/bart-large-cnn",
      inputs: text,
    });
    console.log("Réponse brute résumé:", summary);

    const sentiment = await hf.textClassification({
      model: "distilbert-base-uncased-finetuned-sst-2-english",
      inputs: text,
    });
    console.log("Réponse brute sentiment:", sentiment);
  } catch (err) {
    console.error("Erreur Hugging Face:", err);
  }
}

test();
