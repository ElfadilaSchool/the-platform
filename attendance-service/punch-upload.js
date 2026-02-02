const express = require('express');
const multer = require('multer');
const XLSX = require('xlsx');
const path = require('path');
const fs = require('fs').promises;
const moment = require('moment-timezone');
const { Pool } = require('pg');

const router = express.Router();

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: async (req, file, cb) => {
    const uploadDir = path.join(__dirname, 'uploads');
    try {
      await fs.mkdir(uploadDir, { recursive: true });
      cb(null, uploadDir);
    } catch (error) {
      cb(error);
    }
  },
  filename: (req, file, cb) => {
    const timestamp = Date.now();
    const sanitizedName = file.originalname.replace(/[^a-zA-Z0-9.-]/g, '_');
    cb(null, `${timestamp}_${sanitizedName}`);
  }
});

const upload = multer({
  storage: storage,
  fileFilter: (req, file, cb) => {
    const allowedTypes = [
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/octet-stream'
    ];
    
    if (allowedTypes.includes(file.mimetype) || 
        file.originalname.match(/\.(xls|xlsx)$/i)) {
      cb(null, true);
    } else {
      cb(new Error('Only Excel files (.xls, .xlsx) are allowed'), false);
    }
  },
  limits: {
    fileSize: 10 * 1024 * 1024 // 10MB limit
  }
});

// Parse Excel file and extract punch data
const parseExcelFile = async (filePath) => {
  try {
    const workbook = XLSX.readFile(filePath);
    const sheetName = workbook.SheetNames[0];
    const worksheet = workbook.Sheets[sheetName];
    
    // Convert to JSON with header mapping
    const jsonData = XLSX.utils.sheet_to_json(worksheet, {
      header: 1,
      defval: null
    });

    console.log('Raw Excel Data (first 5 rows):', jsonData.slice(0, 5));

    if (jsonData.length < 2) {
      throw new Error('File must contain at least a header row and one data row');
    }

    const headers = jsonData[0].map(header => (header ? header.toString().trim().toLowerCase() : ''));
    console.log('Excel Headers:', headers);
    console.log('Total rows in file:', jsonData.length);
    const dataRows = jsonData.slice(1);
    console.log('Data rows to process:', dataRows.length);
    
    // Map French headers to English field names (now lowercase)
    const headerMap = {
      // French
      'nom': 'employee_name',
      'date': 'date',
      "heure d'entrée": 'scheduled_in',
      'heure de sortie': 'scheduled_out',
      "pointage d'entrée": 'actual_in',
      'pointage de sortie': 'actual_out',
      'retard': 'late_minutes',
      'départ en avance': 'early_departure',
      // English
      'employee name': 'employee_name',
      'name': 'employee_name',
      'scheduled in': 'scheduled_in',
      'scheduled out': 'scheduled_out',
      'actual in': 'actual_in',
      'actual out': 'actual_out',
      'late minutes': 'late_minutes',
      'early departure': 'early_departure'
    };
    
    // Find column indices
    const columnMap = {};
    headers.forEach((header, index) => {
      const mappedField = headerMap[header];
      if (mappedField) {
        columnMap[mappedField] = index;
      }
    });
    
    // Validate required columns
    const requiredFields = ['employee_name', 'date'];
    const missingFields = requiredFields.filter(field => !(field in columnMap));
    if (missingFields.length > 0) {
      throw new Error(`Missing required columns: ${missingFields.join(', ')}`);
    }
    
    // Parse data rows
    const parsedData = [];
    const errors = [];
    
    dataRows.forEach((row, rowIndex) => {
      try {
        if (!row || row.every(cell => cell === null || cell === '')) {
          return; // Skip empty rows
        }
        
        const employeeName = row[columnMap.employee_name];
        const dateValue = row[columnMap.date];
        
        if (!employeeName || !dateValue) {
          errors.push({
            row: rowIndex + 2,
            error: 'Missing employee name or date'
          });
          return;
        }
        
        // Parse date
        let parsedDate;
        if (typeof dateValue === 'number') {
          // Excel date serial number
          parsedDate = XLSX.SSF.parse_date_code(dateValue);
          parsedDate = new Date(parsedDate.y, parsedDate.m - 1, parsedDate.d);
        } else if (typeof dateValue === 'string') {
          // Try to parse string date (DD/MM/YYYY format)
          const dateParts = dateValue.split('/');
          if (dateParts.length === 3) {
            parsedDate = new Date(dateParts[2], dateParts[1] - 1, dateParts[0]);
          } else {
            parsedDate = new Date(dateValue);
          }
        } else {
          parsedDate = new Date(dateValue);
        }
        
        if (isNaN(parsedDate.getTime())) {
          errors.push({
            row: rowIndex + 2,
            error: 'Invalid date format'
          });
          return;
        }
        
        // Parse time values
        const parseTimeValue = (timeValue) => {
          if (!timeValue) return null;
          
          if (typeof timeValue === 'number') {
            // Excel time serial number (fraction of a day)
            const totalMinutes = Math.round(timeValue * 24 * 60);
            const hours = Math.floor(totalMinutes / 60);
            const minutes = totalMinutes % 60;
            return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`;
          } else if (typeof timeValue === 'string') {
            // Already in HH:MM format
            return timeValue;
          }
          return null;
        };
        
        const record = {
          employee_name: employeeName.toString().trim(),
          date: parsedDate.toISOString().split('T')[0],
          scheduled_in: parseTimeValue(row[columnMap.scheduled_in]),
          scheduled_out: parseTimeValue(row[columnMap.scheduled_out]),
          actual_in: parseTimeValue(row[columnMap.actual_in]),
          actual_out: parseTimeValue(row[columnMap.actual_out]),
          late_minutes: row[columnMap.late_minutes] || null,
          early_departure: row[columnMap.early_departure] || null
        };
        
        parsedData.push(record);
        
      } catch (error) {
        errors.push({
          row: rowIndex + 2,
          error: error.message
        });
      }
    });
    
    return {
      data: parsedData,
      errors: errors,
      totalRows: dataRows.length,
      validRows: parsedData.length,
      success: true
    };
    
  } catch (error) {
    return { success: false, error: `Failed to parse Excel file: ${error.message}` };
  }
};

// Convert parsed data to punch records for preview (no validation)
const convertToPunchRecordsForPreview = (parsedData, uploadId) => {
  console.log('Converting parsed data to punch records. Parsed data length:', parsedData.length);
  const punchRecords = [];

  parsedData.forEach((record, index) => {
    console.log(`Processing record ${index + 1}:`, record);
    const baseDate = record.date;

      // Add punch in record
      if (record.actual_in) {
        console.log(`Adding punch IN for ${record.employee_name} at ${baseDate} ${record.actual_in}`);
        // Use moment.utc to avoid timezone conversion
        const punchTime = moment.utc(`${baseDate} ${record.actual_in}`, 'YYYY-MM-DD HH:mm');
        punchRecords.push({
          employee_name: record.employee_name,
          punch_time: punchTime.toISOString(),
          source: 'upload',
          upload_id: uploadId,
          raw_employee_name: record.employee_name
        });
      } else {
        console.log(`No actual_in time for ${record.employee_name}`);
      }

    // Add punch out record
    if (record.actual_out) {
      console.log(`Adding punch OUT for ${record.employee_name} at ${baseDate} ${record.actual_out}`);
      // Use moment.utc to avoid timezone conversion
      let punchTime = moment.utc(`${baseDate} ${record.actual_out}`, 'YYYY-MM-DD HH:mm');

      // Handle next day punch out (if punch out time is before punch in time)
      if (record.actual_in && record.actual_out < record.actual_in) {
        punchTime.add(1, 'day');
        console.log('Adjusted punch out to next day');
      }

      punchRecords.push({
        employee_name: record.employee_name,
        punch_time: punchTime.toISOString(),
        source: 'upload',
        upload_id: uploadId,
        raw_employee_name: record.employee_name
      });
    } else {
      console.log(`No actual_out time for ${record.employee_name}`);
    }
  });

  console.log('Total punch records generated:', punchRecords.length);
  return punchRecords;
};

// Convert parsed data to punch records for saving (with validation)
const convertToPunchRecordsForSave = async (parsedData, uploadId, pool) => {
  const validRecords = [];
  const errors = [];
  const employeeNameCache = new Map();

  // Pre-fetch all employee names to optimize lookups
  try {
    const allEmployees = await pool.query(`
      SELECT id, first_name, last_name FROM employees
    `);
    allEmployees.rows.forEach(emp => {
      const firstName = emp.first_name.toLowerCase().trim();
      const lastName = emp.last_name.toLowerCase().trim();

      // Variations with space
      employeeNameCache.set(`${firstName} ${lastName}`.replace(/\s+/g, ''), emp.id);
      employeeNameCache.set(`${lastName} ${firstName}`.replace(/\s+/g, ''), emp.id);

      // Variations without space
      employeeNameCache.set(`${firstName}${lastName}`.replace(/\s+/g, ''), emp.id);
      employeeNameCache.set(`${lastName}${firstName}`.replace(/\s+/g, ''), emp.id);
    });
  } catch (error) {
    console.error('Failed to pre-fetch employees:', error);
    throw new Error('Could not load employee data for validation.');
  }

  for (const [index, record] of parsedData.entries()) {
    const employeeName = record.employee_name;
    const employeeId = employeeNameCache.get(employeeName.toLowerCase().trim());

    if (!employeeId) {
      errors.push({
        row: index + 2, // Assuming header is row 1
        error: `Employee not found: '${employeeName}'`
      });
      continue;
    }

    const baseDate = record.date;

    // Add punch in record
    if (record.actual_in) {
      try {
        // Use moment.utc to avoid timezone conversion
        const punchTime = moment.utc(`${baseDate} ${record.actual_in}`, 'YYYY-MM-DD HH:mm');
        if (!punchTime.isValid()) {
          throw new Error(`Invalid 'actual_in' time format: ${record.actual_in}`);
        }
        validRecords.push({
          employee_id: employeeId,
          employee_name: employeeName,
          punch_time: punchTime.toISOString(),
          source: 'upload',
          upload_id: uploadId,
          raw_employee_name: record.employee_name
        });
      } catch (e) {
        errors.push({ row: index + 2, error: e.message });
      }
    }

    // Add punch out record
    if (record.actual_out) {
      try {
        // Use moment.utc to avoid timezone conversion
        let punchTime = moment.utc(`${baseDate} ${record.actual_out}`, 'YYYY-MM-DD HH:mm');
        if (!punchTime.isValid()) {
          throw new Error(`Invalid 'actual_out' time format: ${record.actual_out}`);
        }

        // Handle next day punch out
        if (record.actual_in && record.actual_out < record.actual_in) {
          punchTime.add(1, 'day');
        }

        validRecords.push({
          employee_id: employeeId,
          employee_name: employeeName,
          punch_time: punchTime.toISOString(),
          source: 'upload',
          upload_id: uploadId,
          raw_employee_name: record.employee_name
        });
      } catch (e) {
        errors.push({ row: index + 2, error: e.message });
      }
    }
  }

  return {
    validRecords,
    errors
  };
};

module.exports = {
  router,
  upload,
  parseExcelFile,
  convertToPunchRecordsForPreview,
  convertToPunchRecordsForSave
};