document.addEventListener('DOMContentLoaded', async function() {
    if (!requireAuth()) return;
    const role = authManager.getUserRole();
    if (!role) return;

    const tableBody = document.getElementById('myPayslipsBody');
    try {
        const data = await APIService.payslipsMe();
        tableBody.innerHTML = (data.items || []).map(item => `
          <tr>
            <td>${String(item.month).padStart(2,'0')}</td>
            <td>${item.year}</td>
            <td>
              ${item.payslip_id ? `<a href="#" data-dl="${item.payslip_id}"><i class=\"fas fa-download mr-1\"></i> Download</a>` : '<span class="text-gray-400">No file</span>'}
            </td>
          </tr>
        `).join('');

        tableBody.querySelectorAll('a[data-dl]').forEach(a => {
          a.addEventListener('click', async (e) => {
            e.preventDefault();
            try {
              const id = a.getAttribute('data-dl');
              const blob = await APIService.payslipDownload(id);
              const url = URL.createObjectURL(blob);
              const link = document.createElement('a');
              link.href = url; link.download = 'payslip.pdf';
              document.body.appendChild(link); link.click(); link.remove();
              URL.revokeObjectURL(url);
            } catch (err) { Utils.showNotification('Download failed', 'error'); }
          });
        });
    } catch (err) {
        console.error(err);
        Utils.showNotification('Failed to load payslips', 'error');
    }
});


