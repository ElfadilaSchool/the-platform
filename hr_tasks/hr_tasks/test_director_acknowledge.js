// Test de l'API d'accusé de réception pour le directeur
async function testDirectorAcknowledge() {
  try {
    console.log('🔍 Test de l\'API d\'accusé de réception pour le directeur...');
    
    // Vous devez remplacer ces IDs par de vrais IDs de votre base de données
    const reportId = '2e23504d-0526-4ddb-8ccb-8288e737df92'; // ID d'un rapport existant
    const directorUserId = '79f034a9-ee01-4de2-9238-549e53bb794f'; // ID d'un utilisateur avec rôle Director
    
    console.log('📋 Paramètres de test:');
    console.log('  - Report ID:', reportId);
    console.log('  - Director User ID:', directorUserId);
    
    const response = await fetch(`http://localhost:3004/api/rapportemp/director/${reportId}/acknowledge`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        director_id: directorUserId
      })
    });
    
    console.log('📡 Statut de la réponse:', response.status);
    console.log('📡 Headers:', Object.fromEntries(response.headers.entries()));
    
    const responseText = await response.text();
    console.log('📋 Réponse brute:', responseText);
    
    try {
      const data = JSON.parse(responseText);
      console.log('📋 Réponse JSON:', JSON.stringify(data, null, 2));
      
      if (data.success) {
        console.log('✅ Test réussi ! Accusé de réception enregistré avec succès');
      } else {
        console.log('❌ Test échoué:', data.error);
        if (data.debug_info) {
          console.log('🔍 Informations de debug:', data.debug_info);
        }
      }
    } catch (e) {
      console.log('❌ Réponse n\'est pas du JSON valide');
    }
    
  } catch (error) {
    console.error('❌ Erreur lors du test API:', error.message);
    console.error('Stack:', error.stack);
  }
}

// Fonction pour tester avec différents scénarios
async function testMultipleScenarios() {
  console.log('🧪 Test de plusieurs scénarios...\n');
  
  // Scénario 1: ID utilisateur valide avec rôle Director
  console.log('=== Scénario 1: Utilisateur avec rôle Director ===');
  await testDirectorAcknowledge();
  
  console.log('\n=== Scénario 2: ID utilisateur invalide ===');
  // Scénario 2: ID utilisateur invalide
  try {
    const response = await fetch(`http://localhost:3004/api/rapportemp/director/invalid-id/acknowledge`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ director_id: 'invalid-uuid' })
    });
    const data = await response.json();
    console.log('Réponse:', data);
  } catch (error) {
    console.log('Erreur attendue:', error.message);
  }
  
  console.log('\n=== Scénario 3: Utilisateur sans rôle Director ===');
  // Scénario 3: Utilisateur existant mais sans rôle Director
  // (Vous devez remplacer par un ID d'utilisateur qui existe mais n'a pas le rôle Director)
  try {
    const response = await fetch(`http://localhost:3004/api/rapportemp/director/${reportId}/acknowledge`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ director_id: 'user-id-without-director-role' })
    });
    const data = await response.json();
    console.log('Réponse:', data);
  } catch (error) {
    console.log('Erreur attendue:', error.message);
  }
}

// Attendre un peu que le serveur soit prêt
console.log('⏳ Attente du démarrage du serveur...');
setTimeout(() => {
  testMultipleScenarios();
}, 3000);
