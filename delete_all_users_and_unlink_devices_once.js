const fs = require('fs');

const DATA_FILE = '/data/devices.json';

const raw = fs.readFileSync(DATA_FILE, 'utf8').replace(/^\uFEFF/, '');
const data = JSON.parse(raw);

const usersBefore = Object.keys(data.users || {}).length;
const devices = Object.values(data.devices || {});
let clearedEmails = 0;

for (const device of devices) {
  const hadEmail = Boolean((device && (device.userEmail || device.lastSeenEmail)));
  if (hadEmail) {
    clearedEmails += 1;
  }
  if (device) {
    device.userEmail = null;
    device.lastSeenEmail = null;
  }
}

data.users = {};

fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2));

console.log(
  JSON.stringify(
    {
      usersBefore,
      usersAfter: Object.keys(data.users || {}).length,
      devicesTouched: clearedEmails,
      totalDevices: devices.length,
    },
    null,
    2,
  ),
);
