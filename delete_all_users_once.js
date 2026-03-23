const fs = require('fs');

const DATA_FILE = '/data/devices.json';

const raw = fs.readFileSync(DATA_FILE, 'utf8').replace(/^\uFEFF/, '');
const data = JSON.parse(raw);

const before = Object.keys(data.users || {}).length;
data.users = {};

fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2));

console.log(JSON.stringify({ before, after: Object.keys(data.users || {}).length }, null, 2));
