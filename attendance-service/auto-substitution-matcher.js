/**
 * Automatic Substitution Matcher
 * 
 * When a teacher's leave/holiday exception is approved, this module:
 * 1. Gets the absent teacher's timetable, institution, and level
 * 2. Finds all teachers with free time slots that match
 * 3. Creates invitations for partial or full coverage
 * 4. Supports preschool ↔ primary cross-level matching
 */

const moment = require('moment-timezone');

class AutoSubstitutionMatcher {
  constructor(dbPool) {
    this.pool = dbPool;
  }

  /**
   * Main entry point: Generate substitution invitations from an approved exception
   * @param {uuid} exceptionId - The approved exception ID
   * @param {object} exception - The exception object
   */
  async generateSubstitutionInvitations(exceptionId, exception) {
    const client = await this.pool.connect();
    
    try {
      console.log(`\n🔍 [AUTO-SUB] Processing exception ${exceptionId} for employee ${exception.employee_id}`);
      
      // 1. Check if employee is a teacher
      const employeeResult = await client.query(`
        SELECT e.id, e.first_name, e.last_name, e.institution, e.education_level,
               p.name AS position_name, p.id AS position_id
        FROM employees e
        LEFT JOIN positions p ON e.position_id = p.id
        WHERE e.id = $1
      `, [exception.employee_id]);

      if (employeeResult.rows.length === 0) {
        console.log('❌ [AUTO-SUB] Employee not found');
        return { success: false, message: 'Employee not found' };
      }

      const employee = employeeResult.rows[0];
      
      // Check if position contains "teacher" (case-insensitive)
      const isTeacher = employee.position_name && 
                        employee.position_name.toLowerCase().includes('teacher');
      
      if (!isTeacher) {
        console.log(`ℹ️  [AUTO-SUB] Employee ${employee.first_name} ${employee.last_name} is not a teacher (${employee.position_name}). Skipping auto-substitution.`);
        return { success: true, message: 'Not a teacher - no substitution needed' };
      }

      console.log(`✓ [AUTO-SUB] Employee is a teacher: ${employee.first_name} ${employee.last_name}`);
      console.log(`   Institution: ${employee.institution || 'N/A'}`);
      console.log(`   Level: ${employee.education_level || 'N/A'}`);

      // 2. Get the absent period dates
      const startDate = moment(exception.date);
      const endDate = exception.end_date ? moment(exception.end_date) : startDate;
      console.log(`   Absent period: ${startDate.format('YYYY-MM-DD')} to ${endDate.format('YYYY-MM-DD')}`);
      
      // Validate that we have a proper date range
      if (!startDate.isValid()) {
        console.log('❌ [AUTO-SUB] Invalid start date');
        return { success: false, message: 'Invalid start date' };
      }

      // 3. Get absent teacher's timetable
      const timetable = await this.getEmployeeTimetable(client, exception.employee_id, startDate.toDate());
      
      if (!timetable || !timetable.intervals || timetable.intervals.length === 0) {
        console.log('⚠️  [AUTO-SUB] No timetable found for absent teacher');
        return { success: false, message: 'No timetable found for teacher' };
      }

      console.log(`✓ [AUTO-SUB] Found timetable with ${timetable.intervals.length} interval(s)`);

      // 4. Generate time slots for each day in the absent period
      const absentSlots = this.generateAbsentSlots(startDate, endDate, timetable.intervals);
      console.log(`✓ [AUTO-SUB] Generated ${absentSlots.length} time slot(s) to cover`);

      // 5. Find matching teachers with free time
      const candidates = await this.findMatchingTeachers(
        client, 
        exception.employee_id, 
        employee.institution, 
        employee.education_level,
        absentSlots
      );

      console.log(`✓ [AUTO-SUB] Found ${candidates.length} potential substitute teacher(s)`);

      // 6. Create substitution request if doesn't exist
      const requestId = await this.createSubstitutionRequest(
        client,
        exception.employee_id,
        exception.id,
        startDate.toDate(),
        endDate.toDate(),
        absentSlots
      );

      console.log(`✓ [AUTO-SUB] Created/updated substitution request: ${requestId}`);

      // 7. Create invitations for each candidate with their available slots
      let invitationsCreated = 0;
      console.log(`📤 [AUTO-SUB] Creating invitations for ${candidates.length} candidate(s)...`);
      
      for (const candidate of candidates) {
        console.log(`   👤 Processing candidate: ${candidate.first_name} ${candidate.last_name}`);
        console.log(`      Available slots: ${candidate.availableSlots.length}`);
        
        // Log details about available slots
        candidate.availableSlots.forEach((slot, idx) => {
          const slotType = slot.isPartial ? 'PARTIAL' : 'FULL';
          console.log(`         Slot ${idx + 1}: ${slot.date} ${slot.start_time}-${slot.end_time} (${slot.minutes}min) [${slotType}]`);
        });
        
        const created = await this.createInvitationsForCandidate(
          client,
          requestId,
          candidate,
          absentSlots
        );
        
        console.log(`      ✅ Created ${created} invitation(s) for this candidate`);
        invitationsCreated += created;
      }

      console.log(`🎉 [AUTO-SUB] Successfully created ${invitationsCreated} invitation(s) total`);
      
      return {
        success: true,
        requestId,
        invitationsCreated,
        candidatesFound: candidates.length
      };

    } catch (error) {
      console.error('❌ [AUTO-SUB] Error generating substitutions:', error);
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Get employee's current timetable
   */
  async getEmployeeTimetable(client, employeeId, forDate) {
    const result = await client.query(`
      SELECT t.id, t.name, t.type, t.timezone, t.grade_level_mode, t.grade_level
      FROM employee_timetables et
      JOIN timetables t ON et.timetable_id = t.id
      WHERE et.employee_id = $1
        AND et.effective_from <= $2
        AND (et.effective_to IS NULL OR et.effective_to >= $2)
      ORDER BY et.priority DESC, et.effective_from DESC
      LIMIT 1
    `, [employeeId, forDate]);

    if (result.rows.length === 0) return null;

    const timetable = result.rows[0];

    // Get intervals with grade level information
    const intervalsResult = await client.query(`
      SELECT weekday, start_time, end_time, break_minutes, grade_level
      FROM timetable_intervals
      WHERE timetable_id = $1
      ORDER BY weekday, start_time
    `, [timetable.id]);

    timetable.intervals = intervalsResult.rows;
    return timetable;
  }

  /**
   * Generate absent time slots for each day in the period
   */
  generateAbsentSlots(startDate, endDate, intervals) {
    const slots = [];
    const current = moment(startDate);

    while (current.isSameOrBefore(endDate)) {
      const weekday = current.day(); // 0=Sunday, 1=Monday, etc.
      
      // Find intervals for this weekday
      const dayIntervals = intervals.filter(i => parseInt(i.weekday) === weekday);
      
      dayIntervals.forEach(interval => {
        const [startHour, startMin] = interval.start_time.split(':').map(Number);
        const [endHour, endMin] = interval.end_time.split(':').map(Number);
        
        const slotStart = moment(current).hour(startHour).minute(startMin).second(0);
        const slotEnd = moment(current).hour(endHour).minute(endMin).second(0);
        
        // Calculate duration in minutes
        const durationMinutes = slotEnd.diff(slotStart, 'minutes') - (interval.break_minutes || 0);
        
        if (durationMinutes > 0) {
          slots.push({
            date: current.format('YYYY-MM-DD'),
            weekday,
            start_time: interval.start_time,
            end_time: interval.end_time,
            minutes: durationMinutes,
            grade_level: interval.grade_level,
            occupied: false
          });
        }
      });

      current.add(1, 'day');
    }

    return slots;
  }

  /**
   * Find teachers who can substitute
   * Matches by: institution, level (with preschool↔primary flexibility), and free time
   */
  async findMatchingTeachers(client, absentEmployeeId, institution, level, absentSlots) {
    // Determine allowed levels (preschool can use primary and vice versa)
    const allowedLevels = [level];
    const normalizedLevel = (level || '').toLowerCase();
    
    if (normalizedLevel.includes('preschool') || normalizedLevel.includes('pre-school')) {
      allowedLevels.push('primary', 'Primary', 'PRIMARY', 'pre-school', 'preschool', 'Preschool', 'Pre-School');
    } else if (normalizedLevel.includes('primary')) {
      allowedLevels.push('preschool', 'Preschool', 'pre-school', 'Pre-School', 'PRESCHOOL', 'PRE-SCHOOL');
    }

    // Build level matching condition
    const levelConditions = allowedLevels.map((_, idx) => `e.education_level ILIKE $${idx + 3}`).join(' OR ');

    // Find all teachers in matching institution and level
    const query = `
      SELECT DISTINCT e.id, e.first_name, e.last_name, e.institution, e.education_level,
             p.name AS position_name
      FROM employees e
      LEFT JOIN positions p ON e.position_id = p.id
      WHERE e.id != $1
        AND (e.institution = $2 OR $2 IS NULL)
        AND p.name ILIKE '%teacher%'
        AND (${levelConditions || 'TRUE'})
    `;

    const params = [absentEmployeeId, institution, ...allowedLevels.map(l => `%${l}%`)];
    const result = await client.query(query, params);

    // For each candidate, check their timetable and find free slots
    const candidates = [];
    console.log(`🔍 [AUTO-SUB] Checking ${result.rows.length} potential teacher(s) for availability...`);
    
    if (absentSlots.length === 0) {
      console.log('⚠️  [AUTO-SUB] No absent slots to check - skipping teacher availability check');
      return candidates;
    }
    
    for (const teacher of result.rows) {
      console.log(`   👤 Checking: ${teacher.first_name} ${teacher.last_name} (${teacher.institution}, ${teacher.education_level})`);
      
      const timetable = await this.getEmployeeTimetable(client, teacher.id, moment(absentSlots[0].date).toDate());
      
      if (!timetable) {
        console.log(`      ⚠️  No timetable found - skipping`);
        continue;
      }

      console.log(`      📅 Timetable: ${timetable.name} (${timetable.intervals.length} intervals)`);
      
      const availableSlots = this.findAvailableSlots(teacher, timetable, absentSlots);
      
      console.log(`      🕐 Available slots: ${availableSlots.length}/${absentSlots.length}`);
      
      if (availableSlots.length > 0) {
        candidates.push({
          ...teacher,
          timetable,
          availableSlots
        });
        console.log(`      ✅ Added to candidates list`);
      } else {
        console.log(`      ❌ No available slots - teacher has schedule conflicts`);
      }
    }

    return candidates;
  }

  /**
   * Find which absent slots a teacher can cover based on their timetable
   * Teachers can substitute if they have free time slots that don't conflict
   * Supports partial coverage by finding available time intervals
   */
  findAvailableSlots(teacher, timetable, absentSlots) {
    const available = [];

    for (const absentSlot of absentSlots) {
      if (absentSlot.occupied) continue;

      // Check if teacher has any schedule for this weekday
      const dayIntervals = timetable.intervals.filter(interval => 
        parseInt(interval.weekday) === parseInt(absentSlot.weekday)
      );

      if (dayIntervals.length === 0) {
        // Teacher has no schedule for this day - can cover the entire slot
        available.push(absentSlot);
        continue;
      }

      // Check if teacher has free time that can cover this slot
      const freeSlots = this.findFreeTimeSlots(dayIntervals, absentSlot);
      
      if (freeSlots.length > 0) {
        // Add each free slot as a potential coverage
        freeSlots.forEach(freeSlot => {
          available.push({
            ...absentSlot,
            start_time: freeSlot.start_time,
            end_time: freeSlot.end_time,
            minutes: freeSlot.minutes,
            isPartial: true,
            originalSlot: absentSlot
          });
        });
      }
    }

    return available;
  }

  /**
   * Find free time slots within a teacher's schedule that can cover an absent slot
   */
  findFreeTimeSlots(teacherIntervals, absentSlot) {
    const freeSlots = [];
    
    // Sort teacher intervals by start time
    const sortedIntervals = teacherIntervals.sort((a, b) => a.start_time.localeCompare(b.start_time));
    
    // Check for gaps between scheduled intervals
    for (let i = 0; i < sortedIntervals.length; i++) {
      const current = sortedIntervals[i];
      const next = sortedIntervals[i + 1];
      
      // Check if there's a gap before the first interval
      if (i === 0 && current.start_time > absentSlot.start_time) {
        const gapEnd = this.getEarlierTime(current.start_time, absentSlot.end_time);
        if (gapEnd > absentSlot.start_time) {
          freeSlots.push({
            start_time: absentSlot.start_time,
            end_time: gapEnd,
            minutes: this.calculateMinutes(absentSlot.start_time, gapEnd)
          });
        }
      }
      
      // Check if there's a gap between current and next interval
      if (next) {
        const gapStart = this.getLaterTime(current.end_time, absentSlot.start_time);
        const gapEnd = this.getEarlierTime(next.start_time, absentSlot.end_time);
        
        if (gapStart < gapEnd) {
          freeSlots.push({
            start_time: gapStart,
            end_time: gapEnd,
            minutes: this.calculateMinutes(gapStart, gapEnd)
          });
        }
      }
      
      // Check if there's a gap after the last interval
      if (i === sortedIntervals.length - 1 && current.end_time < absentSlot.end_time) {
        const gapStart = this.getLaterTime(current.end_time, absentSlot.start_time);
        if (gapStart < absentSlot.end_time) {
          freeSlots.push({
            start_time: gapStart,
            end_time: absentSlot.end_time,
            minutes: this.calculateMinutes(gapStart, absentSlot.end_time)
          });
        }
      }
    }
    
    // Filter out slots that are too short (less than 30 minutes)
    return freeSlots.filter(slot => slot.minutes >= 30);
  }

  /**
   * Get the later of two times
   */
  getLaterTime(time1, time2) {
    return time1 > time2 ? time1 : time2;
  }

  /**
   * Get the earlier of two times
   */
  getEarlierTime(time1, time2) {
    return time1 < time2 ? time1 : time2;
  }

  /**
   * Calculate minutes between two times
   */
  calculateMinutes(startTime, endTime) {
    const [startHour, startMin] = startTime.split(':').map(Number);
    const [endHour, endMin] = endTime.split(':').map(Number);
    return (endHour * 60 + endMin) - (startHour * 60 + startMin);
  }

  /**
   * Check if two time ranges overlap
   */
  timesOverlap(start1, end1, start2, end2) {
    return start1 < end2 && start2 < end1;
  }

  /**
   * Create a substitution request record
   */
  async createSubstitutionRequest(client, employeeId, exceptionId, startDate, endDate, slots) {
    // Calculate total minutes
    const totalMinutes = slots.reduce((sum, slot) => sum + slot.minutes, 0);

    // Use first slot for date/time reference
    const firstSlot = slots[0];

    const result = await client.query(`
      INSERT INTO substitution_requests 
      (id, absent_employee_id, exception_id, date, start_time, end_time, total_minutes, grade_level, status, created_at)
      VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, 'pending', CURRENT_TIMESTAMP)
      RETURNING id
    `, [employeeId, exceptionId, firstSlot.date, firstSlot.start_time, firstSlot.end_time, totalMinutes, firstSlot.grade_level]);

    return result.rows[0].id;
  }

  /**
   * Create invitations for a candidate teacher
   */
  async createInvitationsForCandidate(client, requestId, candidate, absentSlots) {
    let created = 0;

    for (const slot of candidate.availableSlots) {
      // Check if invitation already exists
      const existingResult = await client.query(`
        SELECT id FROM substitution_invitations
        WHERE request_id = $1 AND candidate_employee_id = $2 AND date = $3 AND start_time = $4
      `, [requestId, candidate.id, slot.date, slot.start_time]);

      if (existingResult.rows.length === 0) {
        try {
          await client.query(`
            INSERT INTO substitution_invitations 
            (id, request_id, candidate_employee_id, date, start_time, end_time, total_minutes, grade_level, status, created_at)
            VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, 'pending', CURRENT_TIMESTAMP)
          `, [requestId, candidate.id, slot.date, slot.start_time, slot.end_time, slot.minutes, slot.grade_level]);
          
          created++;
          console.log(`         ✅ Created invitation: ${slot.date} ${slot.start_time}-${slot.end_time} (${slot.minutes}min)`);
        } catch (error) {
          console.log(`         ❌ Failed to create invitation: ${error.message}`);
        }
      } else {
        console.log(`         ⚠️  Invitation already exists: ${slot.date} ${slot.start_time}-${slot.end_time}`);
      }
    }

    return created;
  }
}

module.exports = AutoSubstitutionMatcher;

