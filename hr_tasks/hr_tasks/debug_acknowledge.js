// Test direct de l'API d'accusé de réception
async function testAcknowledgeAPI() {
  try {
    console.log('🔍 Test de l\'API d\'accusé de réception...');
    
    const reportId = '2e23504d-0526-4ddb-8ccb-8288e737df92';
    const directorId = '79f034a9-ee01-4de2-9238-549e53bb794f';
    
    console.log('📋 Paramètres:');
    console.log('  - Report ID:', reportId);
    console.log('  - Director ID:', directorId);
    
    const response = await fetch(`http://localhost:3004/api/rapportemp/director/${reportId}/acknowledge`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        director_id: directorId
      })
    });
    
    console.log('📡 Statut de la réponse:', response.status);
    console.log('📡 Headers:', Object.fromEntries(response.headers.entries()));
    
    const responseText = await response.text();
    console.log('📋 Réponse brute:', responseText);
    
    try {
      const data = JSON.parse(responseText);
      console.log('📋 Réponse JSON:', data);
    } catch (e) {
      console.log('❌ Réponse n\'est pas du JSON valide');
    }
    
  } catch (error) {
    console.error('❌ Erreur lors du test API:', error.message);
    console.error('Stack:', error.stack);
  }
}

// Attendre un peu que le serveur soit prêt
setTimeout(testAcknowledgeAPI, 2000);
