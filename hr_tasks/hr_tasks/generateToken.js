require('dotenv').config();
const jwt = require('jsonwebtoken');

// Ici tu peux mettre un utilisateur de test
const payload = {
  userId: 1,            // l'id d'un employé dans ta table employees
  role: 'Department_Responsible', // ou 'HR_Manager', ou 'Employee'
  firstName: 'John',
  lastName: 'Doe'
};

const token = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: '1h' });
console.log('Token généré :', token);
