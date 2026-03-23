const fs = require('fs');

const DATA_FILE = '/data/devices.json';

const raw = fs.readFileSync(DATA_FILE, 'utf8').replace(/^\uFEFF/, '');
const data = JSON.parse(raw);

const summaryBefore = {
  users: Object.keys(data.users || {}).length,
  devices: Object.keys(data.devices || {}).length,
  deviceAliases: Object.keys(data.deviceAliases || {}).length,
  assignments: Array.isArray(data.assignments) ? data.assignments.length : 0,
};

data.users = {};
data.devices = {};
data.deviceAliases = {};
data.assignments = [];

fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2));

const summaryAfter = {
  users: Object.keys(data.users || {}).length,
  devices: Object.keys(data.devices || {}).length,
  deviceAliases: Object.keys(data.deviceAliases || {}).length,
  assignments: Array.isArray(data.assignments) ? data.assignments.length : 0,
};

console.log(JSON.stringify({ summaryBefore, summaryAfter }, null, 2));
