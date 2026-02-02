document.addEventListener('DOMContentLoaded', () => {
  const monthSelect = document.getElementById('monthSelect');
  const yearSelect = document.getElementById('yearSelect');
  const searchInput = document.getElementById('searchInput');
  const departmentFilter = document.getElementById('departmentFilter');

  function populateMonthYear() {
    if (!monthSelect || !yearSelect) return;
    const months = Array.from({ length: 12 }, (_, i) => i + 1);
    monthSelect.innerHTML = months.map(m=>`<option value="${m}">${m}</option>`).join('');
    const y = new Date().getFullYear();
    const years = Array.from({ length: 6 }, (_, i) => y - 3 + i);
    yearSelect.innerHTML = years.map(v=>`<option value="${v}">${v}</option>`).join('');
    monthSelect.value = (new Date().getMonth()+1);
    yearSelect.value = y;
  }

  async function loadDepartments() {
    if (!departmentFilter) return;
    try {
      const data = await APIService.getDepartments();
      departmentFilter.innerHTML = '<option value="">All Departments</option>' + data.map(d=>`<option value="${d.id}">${d.name}</option>`).join('');
    } catch(e) { console.error(e); }
  }

  window.loadSalaries = async function() {
    const params = new URLSearchParams();
    params.append('month', monthSelect.value);
    params.append('year', yearSelect.value);
    if (departmentFilter.value) params.append('departmentId', departmentFilter.value);
    if (searchInput.value) params.append('search', searchInput.value);

    const resp = await authManager.makeAuthenticatedRequest(`${API_SERVICES.salary}/salaries?${params.toString()}`);
    if (!resp.ok) { Utils.showNotification('Failed to load salaries', 'error'); return; }
    const rows = await resp.json();

    document.getElementById('totalEmployees').textContent = rows.length;
    const totalPayroll = rows.reduce((sum, r)=> sum + Number(r.net_salary||0), 0);
    document.getElementById('totalPayroll').textContent = `$${totalPayroll.toFixed(2)}`;

    const body = document.getElementById('salariesTableBody');
    body.innerHTML = rows.map(r => `
      <tr>
        <td class="px-6 py-2">${r.employee}</td>
        <td class="px-6 py-2">${r.position}</td>
        <td class="px-6 py-2">${r.department}</td>
        <td class="px-6 py-2">${r.worked_days}</td>
        <td class="px-6 py-2">$${Number(r.net_salary).toFixed(2)}</td>
        <td class="px-6 py-2">Not Paid</td>
        <td class="px-6 py-2 text-right">
          <button class="text-green-700" onclick="markPaid('${r.employee_id}')">Mark Paid</button>
          <button class="text-blue-700 ml-2" onclick="openRaise('${r.employee_id}')">Add Raise</button>
        </td>
      </tr>`).join('');
  }

  window.openRaise = function(employeeId) {
    document.getElementById('raiseEmployeeId').value = employeeId;
    document.getElementById('raiseModal').classList.remove('hidden');
  }
  window.closeRaiseModal = function(){ document.getElementById('raiseModal').classList.add('hidden'); }

  document.getElementById('raiseForm')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const employeeId = document.getElementById('raiseEmployeeId').value;
    const payload = {
      raise_type: document.getElementById('raiseType').value,
      amount: Number(document.getElementById('raiseAmount').value),
      effective_date: document.getElementById('raiseEffectiveDate').value,
      reason: document.getElementById('raiseReason').value || null,
    };
    const resp = await authManager.makeAuthenticatedRequest(`${API_SERVICES.salary}/salaries/${employeeId}/raises`, {
      method:'POST', headers:{ 'Content-Type':'application/json' }, body: JSON.stringify(payload)
    });
    if (!resp.ok) return Utils.showNotification('Failed to add raise','error');
    Utils.showNotification('Raise added','success');
    closeRaiseModal();
    loadSalaries();
  });

  window.markPaid = async function(employeeId) {
    const resp = await authManager.makeAuthenticatedRequest(`${API_SERVICES.salary}/salaries/${employeeId}/pay`, {
      method:'POST', headers:{ 'Content-Type':'application/json' }, body: JSON.stringify({ month: monthSelect.value, year: yearSelect.value })
    });
    if (!resp.ok) return Utils.showNotification('Failed to mark as paid','error');
    Utils.showNotification('Marked as paid','success');
  }

  window.exportSalaries = async function() {
    const rows = Array.from(document.querySelectorAll('#salariesTableBody tr')).map(tr => {
      const cols = tr.querySelectorAll('td');
      return {
        Employee: cols[0].innerText,
        Position: cols[1].innerText,
        Department: cols[2].innerText,
        WorkedDays: cols[3].innerText,
        NetSalary: cols[4].innerText,
        Status: cols[5].innerText
      };
    });
    await Utils.exportToCSV(rows, `salary_report_${yearSelect.value}_${monthSelect.value}.csv`);
  }

  populateMonthYear();
  loadDepartments();
  loadSalaries();
});
