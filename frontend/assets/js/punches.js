document.addEventListener('DOMContentLoaded', () => {
  const btnPreview = document.getElementById('btnPreview');
  const btnCommit = document.getElementById('btnCommit');
  const dupSel = document.getElementById('duplicateStrategy');
  const fileInput = document.getElementById('punchFile');
  const uploadsList = document.getElementById('uploadsList');
  const previewSection = document.getElementById('previewSection');
  const previewBody = document.getElementById('previewTableBody');
  const uploadSummary = document.getElementById('uploadSummary');
  const refreshUploads = document.getElementById('refreshUploads');

  let tempPayload = null;

  async function loadUploads() {
    try {
      const resp = await authManager.makeAuthenticatedRequest(`${API_SERVICES.attendance}/uploads`);
      if (!resp.ok) throw new Error('Failed to load uploads');
      const data = await resp.json();
      uploadsList.innerHTML = data.map(u => `
        <div class="p-2 border rounded flex justify-between items-center">
          <div>
            <div class="font-medium">${u.original_name}</div>
            <div class="text-xs text-gray-600">${Utils.formatDateTime(u.uploaded_at)} • ${u.file_size} bytes</div>
          </div>
          <div class="space-x-2">
            <a href="${API_SERVICES.attendance}/uploads/${u.id}/download" class="text-blue-600">Download</a>
            <button class="text-red-600" onclick="deleteUpload('${u.id}')">Delete</button>
          </div>
        </div>`).join('');
    } catch(e) { console.error(e); Utils.showNotification('Failed to load uploads','error'); }
  }

  window.deleteUpload = async function(id) {
    if (!confirm('Delete this upload?')) return;
    const resp = await authManager.makeAuthenticatedRequest(`${API_SERVICES.attendance}/uploads/${id}`, { method:'DELETE' });
    if (!resp.ok) return Utils.showNotification('Delete failed','error');
    Utils.showNotification('Deleted','success');
    loadUploads();
  }

  btnPreview?.addEventListener('click', async () => {
    if (!fileInput.files.length) { Utils.showNotification('Select a file first','warning'); return; }
    const fd = new FormData();
    fd.append('file', fileInput.files[0]);
    fd.append('duplicateStrategy', dupSel.value);

    const resp = await authManager.makeAuthenticatedRequest(`${API_SERVICES.attendance}/uploads/preview`, { method:'POST', body: fd });
    if (!resp.ok) { Utils.showNotification('Preview failed','error'); return; }
    const data = await resp.json();
    tempPayload = { ...data.file, duplicateStrategy: dupSel.value };

    previewBody.innerHTML = data.rows.slice(0,200).map(r => `
      <tr>
        <td class="px-4 py-2">${r.employee_name}</td>
        <td class="px-4 py-2">${r.punch_time_utc.substring(0,10)}</td>
        <td class="px-4 py-2">${Utils.formatDateTime(r.punch_time_utc)}</td>
      </tr>`).join('');
    previewSection.classList.remove('hidden');
    uploadSummary.classList.remove('hidden');
    uploadSummary.textContent = `Preview: ${data.rows.length} rows parsed`;
    btnCommit.disabled = false;
  });

  btnCommit?.addEventListener('click', async () => {
    if (!tempPayload) return;
    const resp = await authManager.makeAuthenticatedRequest(`${API_SERVICES.attendance}/uploads/commit`, { method:'POST', headers:{ 'Content-Type':'application/json' }, body: JSON.stringify(tempPayload) });
    if (!resp.ok) { Utils.showNotification('Commit failed','error'); return; }
    const data = await resp.json();
    Utils.showNotification(`Committed: ${data.inserted} inserted, ${data.duplicates} duplicates, ${data.unmatched} unmatched`, 'success');
    btnCommit.disabled = true;
    previewSection.classList.add('hidden');
    loadUploads();
    loadMergedPunches();
  });

  refreshUploads?.addEventListener('click', loadUploads);

  window.loadMergedPunches = async function() {
    const start = document.getElementById('startDate')?.value;
    const end = document.getElementById('endDate')?.value;
    const sortBy = document.getElementById('sortBy')?.value;
    const employee = document.getElementById('employeeSearch')?.value;

    const params = new URLSearchParams();
    if (start) params.append('startDate', start);
    if (end) params.append('endDate', end);
    if (employee) params.append('employee', employee);
    if (sortBy) params.append('sortBy', sortBy);

    const resp = await authManager.makeAuthenticatedRequest(`${API_SERVICES.attendance}/punches?${params.toString()}`);
    if (!resp.ok) { Utils.showNotification('Failed to load punches','error'); return; }
    const data = await resp.json();
    const body = document.getElementById('mergedPunchesBody');
    body.innerHTML = data.rows.map(r => `
      <tr>
        <td class="px-6 py-2">${r.date}</td>
        <td class="px-6 py-2">${r.employee_name}</td>
        <td class="px-6 py-2">${r.department_name || '—'}</td>
        <td class="px-6 py-2">${r.time}</td>
        <td class="px-6 py-2 text-right"><button class="text-blue-600" onclick="openDetail('${r.employee_id}','${r.date}')">Details</button></td>
      </tr>`).join('');
  }

  window.openDetail = async function(employeeId, date) {
    const resp = await authManager.makeAuthenticatedRequest(`${API_SERVICES.attendance}/punches/details?employeeId=${employeeId}&date=${date}`);
    if (!resp.ok) return Utils.showNotification('Failed to load details','error');
    const data = await resp.json();
    const content = `
      <div class="space-y-2">
        ${(data.punches||[]).map(p => `<div class='p-2 bg-gray-50 rounded'>${Utils.formatDateTime(p.punch_time)}</div>`).join('')}
      </div>`;
    document.getElementById('detailTitle').textContent = `Details • ${date}`;
    document.getElementById('detailContent').innerHTML = content;
    document.getElementById('detailModal').classList.remove('hidden');
  }

  window.closeDetail = function(){ document.getElementById('detailModal').classList.add('hidden'); }

  loadUploads();
  loadMergedPunches();
});
