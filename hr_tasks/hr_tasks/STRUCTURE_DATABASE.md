# Structure de la Base de Données - Responsables par Département

## Tables impliquées

### 1. Table `employees`
```sql
- id (uuid, PK)
- first_name (varchar)
- last_name (varchar)
- email (varchar)
- phone (varchar)
- ...
```

### 2. Table `departments`
```sql
- id (uuid, PK)
- name (varchar, UNIQUE)
- responsible_id (uuid, FK vers employees.id)
- created_at (timestamp)
- updated_at (timestamp)
```

### 3. Table `employee_departments` (table de liaison)
```sql
- employee_id (uuid, FK vers employees.id)
- department_id (uuid, FK vers departments.id)
```

## Logique de récupération du responsable

### Requête SQL utilisée :
```sql
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
```

### Explication étape par étape :

1. **`employees emp`** : L'employé pour lequel on cherche le responsable
2. **`employee_departments ed`** : Table de liaison pour trouver les départements de l'employé
3. **`departments d`** : Les départements auxquels appartient l'employé
4. **`employees resp`** : Le responsable de chaque département (via `d.responsible_id`)

### Flux de données :

```
Employé (ID: 123)
    ↓
employee_departments (employee_id = 123)
    ↓
departments (id = department_id)
    ↓
employees (id = responsible_id) ← Le responsable !
```

## APIs disponibles

### 1. Récupérer les départements d'un employé
```
GET /api/rapportemp/employee/:employeeId/departments
```

### 2. Récupérer le responsable du département d'un employé
```
GET /api/rapportemp/responsibles/by-employee/:employeeId
```

## Exemple concret

Si un employé du département "Informatique" se connecte :
1. On trouve ses départements via `employee_departments`
2. On récupère les départements (ex: "Informatique")
3. On trouve le responsable via `departments.responsible_id`
4. On retourne les informations du responsable

## Test

Utilisez le script `test_department_responsible.js` pour tester le bon fonctionnement :

```bash
node test_department_responsible.js
```

Ce script vérifiera :
- Les employés existants
- Les départements existants
- Les relations employé-département
- La récupération des responsables par employé
