const fs = require('fs');
const { exec } = require('child_process');

try {
  const envContent = fs.readFileSync('.env', 'utf8');
  const lines = envContent.split('\n');
  const ports = [];

  lines.forEach(line => {
    const trimmed = line.trim();
    if (trimmed && trimmed.includes('=')) {
      const [key, value] = trimmed.split('=');
      if (key && key.includes('_PORT') && value && !isNaN(value.trim())) {
        ports.push(value.trim());
      }
    }
  });

  // Add port 3020
  ports.push('3020');

  if (ports.length > 0) {
    console.log(`Killing ports: ${ports.join(', ')}`);
    exec(`npx kill-port ${ports.join(' ')}`, (err, stdout, stderr) => {
      if (err) {
        console.error('Error killing ports:', err);
        return;
      }
      console.log('Ports killed successfully');
      if (stdout) console.log(stdout);
      if (stderr) console.error(stderr);
    });
  } else {
    console.log('No ports found in .env');
  }
} catch (error) {
  console.error('Error reading .env file:', error.message);
}
