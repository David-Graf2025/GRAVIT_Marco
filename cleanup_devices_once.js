const fs = require('fs');

const DATA_FILE = '/data/devices.json';

function toStr(value) {
  if (value === undefined || value === null) return '';
  return String(value).trim();
}

function norm(value) {
  return toStr(value).toLowerCase();
}

function toMs(value) {
  const ts = new Date(value).getTime();
  return Number.isFinite(ts) ? ts : 0;
}

function dedupe(data) {
  if (!data || typeof data !== 'object') {
    throw new Error('Invalid devices JSON payload');
  }

  if (!data.devices || typeof data.devices !== 'object') {
    data.devices = {};
  }

  if (!data.deviceAliases || typeof data.deviceAliases !== 'object') {
    data.deviceAliases = {};
  }

  const groups = {};
  for (const device of Object.values(data.devices)) {
    if (!device || typeof device !== 'object') continue;

    const email = norm(device.userEmail || device.lastSeenEmail);
    if (!email) continue;

    // Keep this one-time cleanup conservative: only legacy rows without
    // modern identity markers are considered for merge.
    if (norm(device.fingerprintHash) || norm(device.installationId)) continue;

    const key = [
      email,
      norm(device.platform),
      norm(device.companyId),
      norm(device.tenantId),
    ].join('|');

    if (!groups[key]) groups[key] = [];
    groups[key].push(device);
  }

  const mergedGroups = [];
  let removed = 0;

  for (const [groupKey, list] of Object.entries(groups)) {
    if (!Array.isArray(list) || list.length < 2) continue;

    list.sort((a, b) => toMs(b.lastSeen) - toMs(a.lastSeen));
    const keep = list[0];
    const removedIds = [];

    for (const drop of list.slice(1)) {
      if (!drop || !drop.deviceId || drop.deviceId === keep.deviceId) continue;

      if (Number(drop.appVersion || 0) > Number(keep.appVersion || 0)) {
        keep.appVersion = Number(drop.appVersion || 0);
      }

      if (toMs(drop.createdAt) && (!toMs(keep.createdAt) || toMs(drop.createdAt) < toMs(keep.createdAt))) {
        keep.createdAt = drop.createdAt;
      }

      if (toMs(drop.lastSeen) > toMs(keep.lastSeen)) {
        keep.lastSeen = drop.lastSeen;
      }

      if (toMs(drop.updatedAt) > toMs(keep.updatedAt)) {
        keep.updatedAt = drop.updatedAt;
      }

      const mergedEmail = norm(keep.userEmail || keep.lastSeenEmail || drop.userEmail || drop.lastSeenEmail) || null;
      keep.userEmail = mergedEmail;
      keep.lastSeenEmail = mergedEmail;

      if (!toStr(keep.companyId) && toStr(drop.companyId)) {
        keep.companyId = drop.companyId;
      }

      if (!toStr(keep.tenantId) && toStr(drop.tenantId)) {
        keep.tenantId = drop.tenantId;
      }

      data.deviceAliases[drop.deviceId] = keep.deviceId;
      delete data.devices[drop.deviceId];
      removedIds.push(drop.deviceId);
      removed += 1;
    }

    if (removedIds.length) {
      mergedGroups.push({
        groupKey,
        keptDeviceId: keep.deviceId,
        removedDeviceIds: removedIds,
      });
    }
  }

  return {
    removed,
    mergedGroups,
    remaining: Object.keys(data.devices).length,
    aliasCount: Object.keys(data.deviceAliases).length,
  };
}

function main() {
  const raw = fs.readFileSync(DATA_FILE, 'utf8').replace(/^\uFEFF/, '');
  const data = JSON.parse(raw);

  const summary = dedupe(data);
  fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2));

  console.log(JSON.stringify(summary, null, 2));
}

main();
