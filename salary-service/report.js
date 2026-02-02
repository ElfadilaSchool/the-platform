(function() {
    'use strict';

    // State
    let currentPage = 1;
    let pageSize = 25;
    let sortKey = 'employee_name';
    let sortDir = 'asc';
    let cachedRows = [];
    let charts = { pie: null, bar: null, line: null, fourth: null };
    const SALARY_BASE_URL = (window.SALARY_BASE_URL || 'http://localhost:3010');

    // Utils
    function showToast(type, message) {
        const toast = document.getElementById('toast');
        const icon = document.getElementById('toastIcon');
        const msg = document.getElementById('toastMessage');
        toast.className = 'fixed top-4 right-4 z-50';
        toast.firstElementChild.className = 'bg-white rounded-lg shadow-lg border-l-4 p-4 max-w-sm ' + (type === 'success' ? 'border-green-500' : type === 'warning' ? 'border-yellow-500' : 'border-red-500');
        icon.className = (type === 'success' ? 'fas fa-check-circle text-green-500' : type === 'warning' ? 'fas fa-exclamation-triangle text-yellow-500' : 'fas fa-exclamation-circle text-red-500') + ' text-xl';
        msg.textContent = message;
        toast.classList.remove('hidden');
        setTimeout(() => toast.classList.add('hidden'), 5000);
    }

    function fmtPct(value) {
        if (value == null || isNaN(value)) return '-';
        return `${Math.round(value)}%`;
    }

    function fmtCurrency(amount) {
        return new Intl.NumberFormat('en-US', { style: 'decimal', minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(amount || 0) + ' DA';
    }

    function fmtMinutesToHHMM(totalMinutes) {
        const sign = totalMinutes < 0 ? '-' : '';
        const mins = Math.abs(parseInt(totalMinutes || 0, 10));
        const h = Math.floor(mins / 60);
        const m = mins % 60;
        return `${sign}${String(h).padStart(2,'0')}:${String(m).padStart(2,'0')}`;
    }

    function getFilters() {
        const start = document.getElementById('startDate').value;
        const end = document.getElementById('endDate').value;
        const department = document.getElementById('departmentFilter').value;
        const position = document.getElementById('positionFilter').value;
        const search = document.getElementById('workerSearch').value.trim();

        // Derive year/month if range is within a month; otherwise fallback to current
        let year, month;
        if (start && end) {
            const s = new Date(start), e = new Date(end);
            if (s.getFullYear() === e.getFullYear() && s.getMonth() === e.getMonth()) {
                year = s.getFullYear();
                month = s.getMonth() + 1;
            }
        }
        const now = new Date();
        year = year || now.getFullYear();
        month = month || (now.getMonth() + 1);

        return { start, end, department, position, search, year, month };
    }

    async function loadFilterOptions() {
        try {
            const deptRes = await API.getDepartments(); // attendance departments endpoint
            if (deptRes?.success) {
                const select = document.getElementById('departmentFilter');
                deptRes.departments.forEach(d => {
                    const opt = document.createElement('option');
                    opt.value = d.id; opt.textContent = d.name; select.appendChild(opt);
                });
            }
        } catch (e) { console.warn('Departments load failed', e); }

        // Position list may not have a direct endpoint; derive from employees listing on demand if needed
    }

    // Data fetchers: combine attendance monthly and salaries
    async function fetchData() {
        const f = getFilters();

        // Build inclusive list of {year, month} between start/end if provided; otherwise use single month
        const months = [];
        if (f.start && f.end) {
            const start = new Date((f.start && f.start.length === 7) ? `${f.start}-01` : f.start);
            const end = new Date((f.end && f.end.length === 7) ? `${f.end}-01` : f.end);
            const cur = new Date(start.getFullYear(), start.getMonth(), 1);
            const endMark = new Date(end.getFullYear(), end.getMonth(), 1);
            while (cur <= endMark) {
                months.push({ year: cur.getFullYear(), month: cur.getMonth() + 1 });
                cur.setMonth(cur.getMonth() + 1);
            }
        } else {
            months.push({ year: f.year, month: f.month });
        }

        // Fetch attendance per month and aggregate
        const attendanceAgg = new Map(); // employee_id -> aggregate record
        for (const m of months) {
            const attendanceParams = {
                page: 1,
                limit: 10000,
                year: m.year,
                month: m.month,
                department: f.department || '',
                search: f.search || ''
            };
            let monthly;
            try {
                monthly = await API.getMonthlyAttendance(attendanceParams);
            } catch (e) {
                console.warn('Monthly attendance failed for', m, e);
                monthly = { success: false, data: [] };
            }
            for (const r of (monthly?.data || [])) {
                const prev = attendanceAgg.get(r.employee_id) || {
                    employee_id: r.employee_id,
                    employee_name: r.employee_name,
                    department_name: r.department_name || '',
                    position: r.position || '',
                    scheduled_days: 0,
                    present_days: 0,
                    absent_days: 0,
                    late_count: 0,
                    early_count: 0,
                    late_minutes: 0,
                    early_minutes: 0
                };
                const scheduled = Number(r.scheduled_days) || 0;
                const present = Number(r.worked_days ?? r.present_days) || 0;
                const absent = (r.absence_days != null) ? (Number(r.absence_days) || 0) : Math.max(0, scheduled - present);
                const lateCount = Number(r.late_count) || 0;
                const earlyCount = Number(r.early_count) || 0;
                const lateMinutes = Number(r.late_minutes) || 0;
                const earlyMinutes = Number(r.early_minutes) || 0;
                attendanceAgg.set(r.employee_id, {
                    ...prev,
                    employee_name: prev.employee_name || r.employee_name,
                    department_name: prev.department_name || r.department_name || '',
                    position: prev.position || r.position || '',
                    scheduled_days: Number(prev.scheduled_days) + scheduled,
                    present_days: Number(prev.present_days) + present,
                    absent_days: Number(prev.absent_days) + absent,
                    late_count: Number(prev.late_count) + lateCount,
                    early_count: Number(prev.early_count) + earlyCount,
                    late_minutes: Number(prev.late_minutes) + lateMinutes,
                    early_minutes: Number(prev.early_minutes) + earlyMinutes
                });
            }
        }

        // Fetch salaries per month and aggregate
        const salaryByEmp = new Map(); // employee_id -> { net_salary, department_name, position }
        for (const m of months) {
            const salariesRes = await apiRequest(`${SALARY_BASE_URL}/salaries?${new URLSearchParams({ month: m.month, year: m.year, page: 1, limit: 10000, department: f.department || '' })}`);
            if (salariesRes?.success && Array.isArray(salariesRes.salaries)) {
                for (const s of salariesRes.salaries) {
                    const prev = salaryByEmp.get(s.employee_id) || { net_salary: 0, department_name: s.department_name || '', position: s.position || '', employee_name: s.employee_name || '' };
                    salaryByEmp.set(s.employee_id, {
                        net_salary: Number(prev.net_salary) + (Number(s.net_salary) || 0),
                        department_name: prev.department_name || s.department_name || '',
                        position: prev.position || s.position || '',
                        employee_name: prev.employee_name || s.employee_name || ''
                    });
                }
            }
        }

        // Merge attendance + salary (union of employees in either source)
        const rows = Array.from(attendanceAgg.values()).map(r => {
            const sal = salaryByEmp.get(r.employee_id);
            const scheduled = Number(r.scheduled_days) || 0;
            const present = Number(r.present_days) || 0;
            const absent = (r.absent_days != null) ? (Number(r.absent_days) || 0) : Math.max(0, scheduled - present);
            const attendancePct = scheduled > 0 ? (present / scheduled) * 100 : 0;
            return {
                employee_id: r.employee_id,
                employee_name: r.employee_name,
                department_name: r.department_name || sal?.department_name || '',
                position: r.position || sal?.position || '',
                scheduled_days: scheduled,
                present_days: present,
                absent_days: absent,
                attendance_pct: attendancePct,
                late_count: Number(r.late_count) || 0,
                early_count: Number(r.early_count) || 0,
                late_minutes: Number(r.late_minutes) || 0,
                early_minutes: Number(r.early_minutes) || 0,
                net_salary: (sal && Number(sal.net_salary)) || 0
            };
        });

        // Add employees who appear only in salaries (no attendance rows)
        for (const [empId, s] of salaryByEmp.entries()) {
            if (!attendanceAgg.has(empId)) {
                rows.push({
                    employee_id: empId,
                    employee_name: s.employee_name || '-',
                    department_name: s.department_name || '',
                    position: s.position || '',
                    scheduled_days: 0,
                    present_days: 0,
                    absent_days: 0,
                    attendance_pct: 0,
                    late_count: 0,
                    early_count: 0,
                    late_minutes: 0,
                    early_minutes: 0,
                    net_salary: Number(s.net_salary) || 0
                });
            }
        }

        cachedRows = rows;
        // Populate Position options dynamically based on fetched rows
        try {
            const posSel = document.getElementById('positionFilter');
            if (posSel && posSel.options.length <= 1) {
                const positions = Array.from(new Set(rows.map(r => r.position).filter(Boolean))).sort((a,b)=>a.localeCompare(b));
                positions.forEach(p => { const opt = document.createElement('option'); opt.value = p; opt.textContent = p; posSel.appendChild(opt); });
            }
        } catch (_) {}
        return rows;
    }

    // KPIs
    function renderKpis(rows) {
        const workers = rows.length;
        const avgAttendance = workers ? rows.reduce((a, r) => a + (r.attendance_pct || 0), 0) / workers : 0;
        // Punctuality rate: percentage of days with no late and no early
        const punctualEvents = rows.reduce((a, r) => a + (r.late_count === 0 && r.early_count === 0 ? 1 : 0), 0);
        const punctuality = workers ? (punctualEvents / workers) * 100 : 0;
        const totalSalaries = rows.reduce((a, r) => a + (r.net_salary || 0), 0);
        const departments = new Set(rows.map(r => r.department_name).filter(Boolean)).size;

        document.getElementById('kpiWorkers').textContent = workers;
        document.getElementById('kpiAttendance').textContent = fmtPct(avgAttendance);
        document.getElementById('kpiPunctuality').textContent = fmtPct(punctuality);
        document.getElementById('kpiSalaries').textContent = fmtCurrency(totalSalaries);
        document.getElementById('kpiDepartments').textContent = departments;
    }

    // Charts
    function renderPie(rows) {
        const mode = document.getElementById('pieMetric').value;
        if (charts.pie) charts.pie.destroy();
        if (mode === 'salary') {
            const total = rows.reduce((a, r) => a + (r.net_salary || 0), 0) || 1;
            const paid = total; // all net salaries are considered part of total
            charts.pie = new Chart(document.getElementById('pieChart'), {
                type: 'pie',
                data: {
                    labels: ['Total Salaries'],
                    datasets: [{
                        data: [paid],
                        backgroundColor: ['#f43f5e'],
                        borderColor: '#ffffff',
                        borderWidth: 2,
                        hoverOffset: 8,
                        spacing: 2
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    layout: { padding: 8 },
                    plugins: {
                        legend: { position: 'bottom', labels: { boxWidth: 12, usePointStyle: true } }
                    }
                }
            });
        } else {
            const present = rows.reduce((a, r) => a + (r.present_days || 0), 0);
            const absent = rows.reduce((a, r) => a + (r.absent_days || 0), 0);
            const late = rows.reduce((a, r) => a + (r.late_count || 0), 0);
            const early = rows.reduce((a, r) => a + (r.early_count || 0), 0);
            charts.pie = new Chart(document.getElementById('pieChart'), {
                type: 'pie',
                data: {
                    labels: ['Present', 'Absent', 'Late', 'Early'],
                    datasets: [{
                        data: [present, absent, late, early],
                        backgroundColor: ['#10b981','#ef4444','#f59e0b','#6366f1'],
                        borderColor: '#ffffff',
                        borderWidth: 2,
                        hoverOffset: 8,
                        spacing: 2
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    layout: { padding: 8 },
                    plugins: {
                        legend: { position: 'bottom', labels: { boxWidth: 12, usePointStyle: true } }
                    }
                }
            });
        }
    }

    function renderBar(rows) {
        const metric = document.getElementById('barMetric').value;
        if (charts.bar) charts.bar.destroy();
        if (metric === 'department') {
            const map = new Map();
            rows.forEach(r => {
                const key = r.department_name || 'No Dept';
                const agg = map.get(key) || { count: 0, attendance: 0, salary: 0 };
                agg.count += 1; agg.attendance += r.attendance_pct || 0; agg.salary += r.net_salary || 0; map.set(key, agg);
            });
            // Top 10 departments by total salary to keep chart bounded
            const sorted = Array.from(map.entries()).sort((a,b) => b[1].salary - a[1].salary);
            const top = sorted.slice(0, 10);
            const labels = top.map(([k]) => k);
            const attendance = top.map(([,v]) => v.count ? v.attendance / v.count : 0);
            const salary = top.map(([,v]) => v.salary);
            charts.bar = new Chart(document.getElementById('barChart'), {
                type: 'bar',
                data: { labels, datasets: [
                    { label: 'Avg Attendance %', data: attendance, backgroundColor: '#3b82f6', yAxisID: 'y1' },
                    { label: 'Total Salary (DA)', data: salary, backgroundColor: '#f43f5e', yAxisID: 'y2' }
                ]},
                options: { responsive: true, maintainAspectRatio: false, scales: { y1: { type: 'linear', position: 'left', ticks: { callback: v => `${v}%` } }, y2: { type: 'linear', position: 'right', grid: { drawOnChartArea: false } } } }
            });
        } else {
            const topRows = rows.slice().sort((a,b) => (b.net_salary || 0) - (a.net_salary || 0)).slice(0, 12);
            const labels = topRows.map(r => r.employee_name);
            const attendance = topRows.map(r => Math.round(r.attendance_pct || 0));
            const salary = topRows.map(r => r.net_salary || 0);
            charts.bar = new Chart(document.getElementById('barChart'), {
                type: 'bar',
                data: { labels, datasets: [
                    { label: 'Attendance %', data: attendance, backgroundColor: '#3b82f6', yAxisID: 'y1' },
                    { label: 'Net Salary (DA)', data: salary, backgroundColor: '#10b981', yAxisID: 'y2' }
                ]},
                options: { responsive: true, maintainAspectRatio: false, scales: { y1: { type: 'linear', position: 'left', ticks: { callback: v => `${v}%` } }, y2: { type: 'linear', position: 'right', grid: { drawOnChartArea: false } } } }
            });
        }
    }

    function monthKey(year, month) { return `${year}-${String(month).padStart(2,'0')}`; }

    function renderLine(rows) {
        const mode = document.getElementById('lineMetric').value;
        if (charts.line) charts.line.destroy();
        // Build trend based on selected date range (or fallback to last 6 months)
        const f = getFilters();
        const monthTuples = [];
        if (f.start && f.end) {
            const start = new Date((f.start && f.start.length === 7) ? `${f.start}-01` : f.start);
            const end = new Date((f.end && f.end.length === 7) ? `${f.end}-01` : f.end);
            const cur = new Date(start.getFullYear(), start.getMonth(), 1);
            const endMark = new Date(end.getFullYear(), end.getMonth(), 1);
            while (cur <= endMark) {
                monthTuples.push({ year: cur.getFullYear(), month: cur.getMonth() + 1 });
                cur.setMonth(cur.getMonth() + 1);
            }
        } else {
            const now = new Date();
            for (let i = 5; i >= 0; i--) {
                const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
                monthTuples.push({ year: d.getFullYear(), month: d.getMonth() + 1 });
            }
        }
        const labels = monthTuples.map(m => `${m.year}-${String(m.month).padStart(2,'0')}`);
        const dataset = labels.map(() => 0);
        charts.line = new Chart(document.getElementById('lineChart'), {
            type: 'line',
            data: { labels, datasets: [{ label: mode === 'salary' ? 'Total Salary (DA)' : 'Avg Attendance %', data: dataset, borderColor: '#6366f1', backgroundColor: 'rgba(99,102,241,0.2)', fill: true }]},
            options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: true } } }
        });
        // Lazy load series values to avoid multiple server calls before first paint
        (async () => {
            for (let idx = 0; idx < monthTuples.length; idx++) {
                const { year: y, month: m } = monthTuples[idx];
                try {
                    if (mode === 'salary') {
                        const params = { year: y, month: m, page: 1, limit: 10000 };
                        if (f.department) params.department = f.department;
                        const res = await apiRequest(`${SALARY_BASE_URL}/salaries?${new URLSearchParams(params)}`);
                        const total = (res?.salaries || []).reduce((a, s) => a + (s.net_salary || 0), 0);
                        charts.line.data.datasets[0].data[idx] = total;
                    } else {
                        const attendanceParams = { year: y, month: m, page: 1, limit: 10000 };
                        if (f.department) attendanceParams.department = f.department;
                        if (f.search) attendanceParams.search = f.search;
                        const res = await API.getMonthlyAttendance(attendanceParams);
                        const rowsM = res?.data || [];
                        const avg = rowsM.length ? rowsM.reduce((a, r) => a + (((r.worked_days || r.present_days || 0) / (r.scheduled_days || 0 || 1)) * 100), 0) / rowsM.length : 0;
                        charts.line.data.datasets[0].data[idx] = Math.round(avg);
                    }
                    charts.line.update('none');
                } catch (_) {}
            }
        })();
    }

    function renderFourth(rows) {
        if (charts.fourth) charts.fourth.destroy();
        // Doughnut: share of payroll by department (top 6 + Others)
        const byDept = new Map();
        rows.forEach(r => {
            const k = r.department_name || 'No Dept';
            byDept.set(k, (byDept.get(k) || 0) + (r.net_salary || 0));
        });
        const sorted = Array.from(byDept.entries()).sort((a,b) => b[1]-a[1]);
        const top = sorted.slice(0, 6);
        const others = sorted.slice(6).reduce((a, [,v]) => a+v, 0);
        const labels = top.map(([k]) => k).concat(others > 0 ? ['Others'] : []);
        const data = top.map(([,v]) => v).concat(others > 0 ? [others] : []);
        charts.fourth = new Chart(document.getElementById('fourthChart'), {
            type: 'doughnut',
            data: { labels, datasets: [{ data, backgroundColor: ['#60a5fa','#34d399','#f472b6','#fbbf24','#a78bfa','#ef4444','#9ca3af'] }] },
            options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { position: 'bottom' } } }
        });
    }

    // Table
    function applySorting(rows) {
        const dir = sortDir === 'asc' ? 1 : -1;
        return [...rows].sort((a, b) => {
            const va = a[sortKey]; const vb = b[sortKey];
            if (va == null && vb == null) return 0; if (va == null) return -1 * dir; if (vb == null) return 1 * dir;
            if (typeof va === 'string') return va.localeCompare(vb) * dir;
            return (va - vb) * dir;
        });
    }

    function renderTable(rows) {
        const sorted = applySorting(rows);
        const start = (currentPage - 1) * pageSize;
        const paged = sorted.slice(start, start + pageSize);
        const tbody = document.getElementById('reportTableBody');
        tbody.innerHTML = paged.map(r => `
            <tr>
                <td class="px-4 py-3 whitespace-nowrap">
                    <div class="text-sm font-medium text-gray-900">${r.employee_name || '-'}</div>
                    <div class="text-xs text-gray-500">${(r.department_name || '—')} — ${(r.position || '—')}</div>
                </td>
                <td class="px-4 py-3 text-sm text-gray-900">${r.scheduled_days || 0}</td>
                <td class="px-4 py-3 text-sm text-gray-900">${r.present_days || 0}</td>
                <td class="px-4 py-3 text-sm text-gray-900">${r.absent_days || 0}</td>
                <td class="px-4 py-3 text-sm text-gray-900">${fmtPct(r.attendance_pct)}</td>
                <td class="px-4 py-3 text-sm text-gray-900">${(r.late_count || 0)} / ${fmtMinutesToHHMM(r.late_minutes)}</td>
                <td class="px-4 py-3 text-sm text-gray-900">${(r.early_count || 0)} / ${fmtMinutesToHHMM(r.early_minutes)}</td>
                <td class="px-4 py-3 text-sm text-gray-900">${fmtCurrency(r.net_salary)}</td>
            </tr>
        `).join('');

        const total = rows.length;
        const end = Math.min(start + pageSize, total);
        document.getElementById('paginationInfo').textContent = `Showing ${start + 1} to ${end} of ${total} workers`;
        const pages = Math.max(1, Math.ceil(total / pageSize));
        document.getElementById('pageIndicator').textContent = `Page ${currentPage} of ${pages}`;
        document.getElementById('prevPageBtn').disabled = currentPage <= 1;
        document.getElementById('nextPageBtn').disabled = currentPage >= pages;
    }

    function applyClientFilters(rows) {
        const f = getFilters();
        let filtered = rows;
        if (f.position) filtered = filtered.filter(r => (r.position || '') === f.position);
        if (f.search) {
            const q = f.search.toLowerCase();
            filtered = filtered.filter(r => (r.employee_name || '').toLowerCase().includes(q));
        }
        return filtered;
    }

    async function refreshAll() {
        try {
            const rows = await fetchData();
            const viewRows = applyClientFilters(rows);
            renderKpis(viewRows);
            renderPie(viewRows);
            renderBar(viewRows);
            renderFourth(viewRows);
            renderLine(viewRows);
            renderTable(viewRows);
        } catch (e) {
            console.error(e);
            showToast('error', e.message || 'Failed to load report');
        }
    }

    function bindEvents() {
        document.getElementById('applyFiltersBtn').addEventListener('click', () => { currentPage = 1; refreshAll(); });
        document.getElementById('startDate').addEventListener('change', () => { currentPage = 1; renderLine(applyClientFilters(cachedRows)); });
        document.getElementById('endDate').addEventListener('change', () => { currentPage = 1; renderLine(applyClientFilters(cachedRows)); });
        document.getElementById('positionFilter').addEventListener('change', () => { currentPage = 1; const rows = applyClientFilters(cachedRows); renderKpis(rows); renderPie(rows); renderBar(rows); renderFourth(rows); renderTable(rows); renderLine(rows); });
        document.getElementById('workerSearch').addEventListener('input', () => { currentPage = 1; const rows = applyClientFilters(cachedRows); renderKpis(rows); renderPie(rows); renderBar(rows); renderFourth(rows); renderTable(rows); renderLine(rows); });
        document.getElementById('refreshBtn').addEventListener('click', () => refreshAll());
        document.getElementById('pieMetric').addEventListener('change', () => renderPie(applyClientFilters(cachedRows)));
        document.getElementById('barMetric').addEventListener('change', () => renderBar(applyClientFilters(cachedRows)));
        document.getElementById('lineMetric').addEventListener('change', () => renderLine(cachedRows));
        document.getElementById('prevPageBtn').addEventListener('click', () => { if (currentPage > 1) { currentPage--; renderTable(cachedRows); } });
        document.getElementById('nextPageBtn').addEventListener('click', () => { currentPage++; renderTable(cachedRows); });
        document.getElementById('toastClose').addEventListener('click', () => document.getElementById('toast').classList.add('hidden'));

        // Simple header sort by clicking headings
        const headers = ['employee_name','scheduled_days','present_days','absent_days','attendance_pct','late_minutes','early_minutes','net_salary'];
        const thead = document.querySelector('thead tr');
        if (thead) {
            Array.from(thead.children).forEach((th, idx) => {
                if (idx === 0) th.style.cursor = 'pointer';
                th.addEventListener('click', () => {
                    const key = headers[idx];
                    if (!key) return;
                    if (sortKey === key) sortDir = sortDir === 'asc' ? 'desc' : 'asc'; else { sortKey = key; sortDir = 'asc'; }
                    renderTable(cachedRows);
                });
            });
        }

        // PDF export
        document.getElementById('exportPdfBtn').addEventListener('click', async () => {
            try {
                const { jsPDF } = window.jspdf;
                const pdf = new jsPDF('p', 'pt', 'a4');
                const root = document.getElementById('reportRoot');
                // Header info
                const f = getFilters();
                const title = `Attendance & Salary Report`;
                const subtitle = `Filters: ${f.start || '—'} to ${f.end || '—'} | Dept: ${f.department || 'All'} | Worker: ${f.search || 'All'} | Generated: ${new Date().toLocaleString()}`;
                pdf.setFontSize(16); pdf.text(title, 40, 40);
                pdf.setFontSize(10); pdf.text(subtitle, 40, 58);

                const canvas = await html2canvas(root, { scale: 2, useCORS: true, backgroundColor: '#ffffff' });
                const imgData = canvas.toDataURL('image/png');
                const pageWidth = pdf.internal.pageSize.getWidth();
                const pageHeight = pdf.internal.pageSize.getHeight();
                const imgWidth = pageWidth - 80; // margins
                const imgHeight = canvas.height * imgWidth / canvas.width;

                let y = 80;
                let remainingHeight = imgHeight;
                let sY = 0;
                while (remainingHeight > 0) {
                    const pageCanvas = document.createElement('canvas');
                    pageCanvas.width = canvas.width;
                    const sliceHeight = Math.min(canvas.height - sY, Math.floor((pageHeight - y) * (canvas.width / imgWidth)));
                    pageCanvas.height = sliceHeight;
                    const ctx = pageCanvas.getContext('2d');
                    ctx.drawImage(canvas, 0, sY, canvas.width, sliceHeight, 0, 0, canvas.width, sliceHeight);
                    const pageImgData = pageCanvas.toDataURL('image/png');
                    const pageImgHeight = sliceHeight * (imgWidth / canvas.width);
                    pdf.addImage(pageImgData, 'PNG', 40, y, imgWidth, pageImgHeight);
                    sY += sliceHeight;
                    remainingHeight -= pageImgHeight;
                    if (sY < canvas.height) { pdf.addPage(); y = 40; }
                }
                pdf.save(`report-${new Date().toISOString().slice(0,10)}.pdf`);
            } catch (e) {
                console.error('PDF export failed', e);
                showToast('error', 'PDF export failed');
            }
        });
    }

    function setDefaultDates() {
        const s = document.getElementById('startDate');
        const e = document.getElementById('endDate');
        const now = new Date();
        const yyyy = now.getFullYear();
        const mm = String(now.getMonth() + 1).padStart(2, '0');
        const ym = `${yyyy}-${mm}`;
        s.value = ym;
        e.value = ym;
    }

    document.addEventListener('DOMContentLoaded', async function() {
        if (typeof checkAuth === 'function') { if (!checkAuth()) return; }
        setDefaultDates();
        await loadFilterOptions();
        bindEvents();
        // Default Trend metric to salary
        const lineMetricSel = document.getElementById('lineMetric');
        if (lineMetricSel) lineMetricSel.value = 'salary';
        refreshAll();
    });
})();


