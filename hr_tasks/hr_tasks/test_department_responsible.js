// Script de test pour vérifier l'API des responsables par département
const API = 'http://localhost:3004';

async function testDepartmentResponsible() {
    console.log('🧪 Test de l\'API des responsables par département...\n');
    
    try {
        // Test 1: Récupérer tous les employés
        console.log('1️⃣ Récupération de tous les employés...');
        const employeesResponse = await fetch(`${API}/employees`);
        const employees = await employeesResponse.json();
        
        console.log(`✅ ${employees.length} employés trouvés`);
        employees.forEach(emp => {
            console.log(`   - ${emp.first_name} ${emp.last_name} (ID: ${emp.id})`);
        });
        
        // Test 2: Récupérer tous les départements
        console.log('\n2️⃣ Récupération de tous les départements...');
        const departmentsResponse = await fetch(`${API}/departments`);
        const departments = await departmentsResponse.json();
        
        console.log(`✅ ${departments.length} départements trouvés`);
        departments.forEach(dept => {
            console.log(`   - ${dept.name} (Responsable ID: ${dept.responsible_id})`);
        });
        
        // Test 3: Vérifier la table employee_departments
        console.log('\n3️⃣ Vérification des relations employé-département...');
        try {
            // Cette requête nous montrera les relations existantes
            const relationsResponse = await fetch(`${API}/departments`);
            const depts = await relationsResponse.json();
            
            for (const dept of depts) {
                const empResponse = await fetch(`${API}/departments/${dept.id}/employees`);
                const deptEmployees = await empResponse.json();
                console.log(`   📁 ${dept.name}: ${deptEmployees.length} employé(s)`);
            }
        } catch (error) {
            console.log(`   ⚠️  Impossible de vérifier les relations: ${error.message}`);
        }
        
        // Test 4: Vérifier les départements de chaque employé
        console.log('\n4️⃣ Vérification des départements par employé...');
        for (const employee of employees.slice(0, 3)) { // Tester avec les 3 premiers employés
            try {
                const deptResponse = await fetch(`${API}/api/rapportemp/employee/${employee.id}/departments`);
                const deptData = await deptResponse.json();
                
                console.log(`\n   👤 Employé: ${employee.first_name} ${employee.last_name} (ID: ${employee.id})`);
                if (deptData.success && deptData.departments.length > 0) {
                    deptData.departments.forEach(dept => {
                        console.log(`   📁 Département: ${dept.name} (Responsable ID: ${dept.responsible_id})`);
                    });
                } else {
                    console.log(`   ⚠️  Aucun département trouvé pour cet employé`);
                }
            } catch (error) {
                console.log(`   ❌ Erreur pour l'employé ${employee.id}: ${error.message}`);
            }
        }
        
        // Test 5: Tester l'API des responsables par employé
        console.log('\n5️⃣ Test de l\'API des responsables par employé...');
        for (const employee of employees.slice(0, 3)) { // Tester avec les 3 premiers employés
            try {
                const response = await fetch(`${API}/api/rapportemp/responsibles/by-employee/${employee.id}`);
                const data = await response.json();
                
                console.log(`\n   👤 Employé: ${employee.first_name} ${employee.last_name} (ID: ${employee.id})`);
                if (data.success && data.responsibles.length > 0) {
                    data.responsibles.forEach(resp => {
                        console.log(`   ✅ Responsable: ${resp.first_name} ${resp.last_name} (Département: ${resp.department_name})`);
                    });
                } else {
                    console.log(`   ⚠️  Aucun responsable trouvé pour cet employé`);
                }
            } catch (error) {
                console.log(`   ❌ Erreur pour l'employé ${employee.id}: ${error.message}`);
            }
        }
        
        console.log('\n🎉 Test terminé !');
        
    } catch (error) {
        console.error('❌ Erreur lors du test:', error);
    }
}

// Exécuter le test
testDepartmentResponsible();
