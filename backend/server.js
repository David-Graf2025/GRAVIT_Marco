const express = require('express');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = Number(process.env.PORT || 3000);
const DATA_FILE = process.env.DATA_FILE || '/data/devices.json';
const DASHBOARD_FILE = path.join(__dirname, 'dashboard.html');
const ADMIN_AUTH_USERNAME = toStr(process.env.ADMIN_AUTH_USERNAME);
const ADMIN_AUTH_PASSWORD = toStr(process.env.ADMIN_AUTH_PASSWORD);
const ADMIN_AUTH_REALM = toStr(process.env.ADMIN_AUTH_REALM) || 'BilderApp Admin';
const ADMIN_AUTH_ENABLED = ADMIN_AUTH_USERNAME.length > 0 && ADMIN_AUTH_PASSWORD.length > 0;
const DATA_BACKUP_DIR = process.env.DATA_BACKUP_DIR || path.join(path.dirname(DATA_FILE), 'backups');
const DATA_BACKUP_KEEP = Number.parseInt(process.env.DATA_BACKUP_KEEP || '20', 10);

app.use(express.json({ limit: '5mb' }));

function parseBasicAuthHeader(headerValue) {
  const raw = toStr(headerValue);
  if (!raw.toLowerCase().startsWith('basic ')) return null;

  try {
    const encoded = raw.slice(6).trim();
    const decoded = Buffer.from(encoded, 'base64').toString('utf8');
    const separatorIndex = decoded.indexOf(':');
    if (separatorIndex < 0) return null;

    return {
      username: decoded.slice(0, separatorIndex),
      password: decoded.slice(separatorIndex + 1),
    };
  } catch (_err) {
    return null;
  }
}

function requireAdminAuth(req, res, next) {
  if (!ADMIN_AUTH_ENABLED) return next();

  const credentials = parseBasicAuthHeader(req.headers && req.headers.authorization);
  const isValid =
    !!credentials &&
    credentials.username === ADMIN_AUTH_USERNAME &&
    credentials.password === ADMIN_AUTH_PASSWORD;

  if (!isValid) {
    res.set('WWW-Authenticate', `Basic realm="${ADMIN_AUTH_REALM}", charset="UTF-8"`);
    return res.status(401).json({ error: 'Admin authentication required' });
  }

  return next();
}

app.use('/admin', requireAdminAuth);

function nowIso() {
  return new Date().toISOString();
}

function toStr(value) {
  if (value === undefined || value === null) return '';
  return String(value).trim();
}

function toLowerEmail(value) {
  return toStr(value).toLowerCase();
}

function toBool(value, fallback = false) {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  if (typeof value === 'string') {
    const v = value.trim().toLowerCase();
    if (v === 'true' || v === '1' || v === 'yes') return true;
    if (v === 'false' || v === '0' || v === 'no') return false;
  }
  return fallback;
}

function cloneDataState(source) {
  return JSON.parse(JSON.stringify(source));
}

function restoreDataState(snapshot) {
  data = normalizeData(snapshot);
  ensureModelConsistency();
}

function parseIsoMs(value) {
  const ts = new Date(value).getTime();
  return Number.isFinite(ts) ? ts : null;
}

function minIso(a, b) {
  if (!a) return b || null;
  if (!b) return a || null;
  const ta = parseIsoMs(a);
  const tb = parseIsoMs(b);
  if (ta === null) return b;
  if (tb === null) return a;
  return ta <= tb ? a : b;
}

function maxIso(a, b) {
  if (!a) return b || null;
  if (!b) return a || null;
  const ta = parseIsoMs(a);
  const tb = parseIsoMs(b);
  if (ta === null) return b;
  if (tb === null) return a;
  return ta >= tb ? a : b;
}

function resolveCanonicalDeviceId(deviceId) {
  let current = toStr(deviceId);
  if (!current) return '';

  const seen = new Set();
  while (
    current &&
    data &&
    data.deviceAliases &&
    data.deviceAliases[current] &&
    !seen.has(current)
  ) {
    seen.add(current);
    current = toStr(data.deviceAliases[current]);
  }

  return current;
}

function setDeviceAlias(aliasId, canonicalId) {
  const alias = toStr(aliasId);
  const canonical = toStr(canonicalId);
  if (!alias || !canonical || alias === canonical) return;

  if (!data.deviceAliases || typeof data.deviceAliases !== 'object') {
    data.deviceAliases = {};
  }

  data.deviceAliases[alias] = canonical;
}

function rewriteAliasesTarget(fromDeviceId, toDeviceId) {
  const fromId = toStr(fromDeviceId);
  const toId = toStr(toDeviceId);
  if (!fromId || !toId || fromId === toId) return;

  if (!data.deviceAliases || typeof data.deviceAliases !== 'object') {
    data.deviceAliases = {};
  }

  for (const [alias, canonical] of Object.entries(data.deviceAliases)) {
    if (toStr(canonical) === fromId) {
      if (toStr(alias) === toId) {
        delete data.deviceAliases[alias];
      } else {
        data.deviceAliases[alias] = toId;
      }
    }
  }

  data.deviceAliases[fromId] = toId;
  if (data.deviceAliases[toId] === toId) {
    delete data.deviceAliases[toId];
  }
}

function chooseCanonicalDevice(deviceA, deviceB) {
  const a = deviceA || {};
  const b = deviceB || {};

  const aAssigned = !!toStr(a.companyId);
  const bAssigned = !!toStr(b.companyId);
  if (aAssigned !== bAssigned) return aAssigned ? a : b;

  const aEmail = toLowerEmail(a.userEmail || a.lastSeenEmail);
  const bEmail = toLowerEmail(b.userEmail || b.lastSeenEmail);
  if (!!aEmail !== !!bEmail) return aEmail ? a : b;

  const aFingerprint = toStr(a.fingerprintHash);
  const bFingerprint = toStr(b.fingerprintHash);
  if (!!aFingerprint !== !!bFingerprint) return aFingerprint ? a : b;

  const aCreated = parseIsoMs(a.createdAt);
  const bCreated = parseIsoMs(b.createdAt);
  if (aCreated !== null && bCreated !== null) {
    return aCreated <= bCreated ? a : b;
  }

  return a;
}

function mergeDeviceRecords(targetDevice, sourceDevice) {
  if (!targetDevice || !sourceDevice || targetDevice === sourceDevice) return targetDevice;

  targetDevice.createdAt = minIso(targetDevice.createdAt, sourceDevice.createdAt) || nowIso();
  targetDevice.updatedAt = maxIso(targetDevice.updatedAt, sourceDevice.updatedAt) || nowIso();
  targetDevice.lastSeen = maxIso(targetDevice.lastSeen, sourceDevice.lastSeen) || targetDevice.lastSeen;
  targetDevice.graceUntil = maxIso(targetDevice.graceUntil, sourceDevice.graceUntil);

  targetDevice.allowed = toBool(targetDevice.allowed, true) && toBool(sourceDevice.allowed, true);
  if (!targetDevice.message && sourceDevice.message) {
    targetDevice.message = sourceDevice.message;
  }

  if ((!targetDevice.platform || targetDevice.platform === 'unknown') && sourceDevice.platform) {
    targetDevice.platform = sourceDevice.platform;
  }

  const sourceAppVersion = Number.isFinite(Number(sourceDevice.appVersion))
    ? Number(sourceDevice.appVersion)
    : 0;
  const targetAppVersion = Number.isFinite(Number(targetDevice.appVersion))
    ? Number(targetDevice.appVersion)
    : 0;
  if (sourceAppVersion > targetAppVersion) {
    targetDevice.appVersion = sourceAppVersion;
  }

  targetDevice.companyId = toStr(targetDevice.companyId) || toStr(sourceDevice.companyId) || null;
  targetDevice.tenantId = toStr(targetDevice.tenantId) || toStr(sourceDevice.tenantId) || null;

  const mergedEmail =
    toLowerEmail(targetDevice.userEmail || targetDevice.lastSeenEmail) ||
    toLowerEmail(sourceDevice.userEmail || sourceDevice.lastSeenEmail) ||
    null;
  targetDevice.userEmail = mergedEmail;
  targetDevice.lastSeenEmail = mergedEmail;

  targetDevice.installationId =
    toStr(targetDevice.installationId) || toStr(sourceDevice.installationId) || null;
  targetDevice.fingerprintHash =
    toStr(targetDevice.fingerprintHash) || toStr(sourceDevice.fingerprintHash) || null;

  const targetAssigned = toStr(targetDevice.assignmentStatus) === 'assigned';
  const sourceAssigned = toStr(sourceDevice.assignmentStatus) === 'assigned';
  targetDevice.assignmentStatus = targetAssigned || sourceAssigned || targetDevice.companyId
    ? 'assigned'
    : 'unassigned';
  targetDevice.assignmentUpdatedAt =
    maxIso(targetDevice.assignmentUpdatedAt, sourceDevice.assignmentUpdatedAt) || null;
  targetDevice.assignmentUpdatedBy =
    toStr(targetDevice.assignmentUpdatedBy) || toStr(sourceDevice.assignmentUpdatedBy) || null;

  return targetDevice;
}

function ensureDirForFile(filePath) {
  const dir = path.dirname(filePath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function normalizedBackupKeepCount() {
  if (Number.isFinite(DATA_BACKUP_KEEP) && DATA_BACKUP_KEEP >= 0) {
    return Math.floor(DATA_BACKUP_KEEP);
  }
  return 20;
}

function createDataBackupSnapshot() {
  if (!fs.existsSync(DATA_FILE)) return true;

  try {
    fs.mkdirSync(DATA_BACKUP_DIR, { recursive: true });

    const stamp = nowIso().replace(/[:.]/g, '-');
    const snapshotFile = path.join(DATA_BACKUP_DIR, `devices-${stamp}.json`);
    fs.copyFileSync(DATA_FILE, snapshotFile);

    const keepCount = normalizedBackupKeepCount();
    if (keepCount === 0) {
      // keepCount=0 means keep no history and remove the newly created snapshot.
      fs.unlinkSync(snapshotFile);
      return true;
    }

    const snapshots = fs
      .readdirSync(DATA_BACKUP_DIR)
      .filter((name) => name.startsWith('devices-') && name.endsWith('.json'))
      .map((name) => {
        const fullPath = path.join(DATA_BACKUP_DIR, name);
        const stat = fs.statSync(fullPath);
        return { fullPath, mtimeMs: stat.mtimeMs };
      })
      .sort((a, b) => b.mtimeMs - a.mtimeMs);

    for (let idx = keepCount; idx < snapshots.length; idx += 1) {
      fs.unlinkSync(snapshots[idx].fullPath);
    }

    return true;
  } catch (err) {
    console.error('Error creating data backup snapshot:', err.message);
    return false;
  }
}

function defaultData() {
  return {
    schemaVersion: 3,
    debugMode: false,
    companies: {},
    users: {},
    devices: {},
    deviceAliases: {},
    tenantConfigs: {},
    domainTenantMapping: {},
    defaultTenantId: 'gravit_default',
    manualTenantId: '',
    assignments: [],
  };
}

const PLATFORM_DEFAULTS = {
  defaultTenantId: 'gravit_default',
  defaultFolderNamingTemplate: '{city} {siteId} {netElement} {project}',
  defaultFileNamingTemplate: '{netElement}_{project}_{photoVar}.jpg',
  defaultFields: [
    { key: 'city', type: 'text', label: 'Stadt', required: true },
    { key: 'siteId', type: 'text', label: 'Standort-ID', required: true },
    { key: 'netElement', type: 'text', label: 'Netzelementnummer', required: false },
    { key: 'project', type: 'text', label: 'Projektnummer', required: false },
  ],
  defaultPhotoVariables: [
    'vor Umbau',
    'Erdung_1',
    'Erdung_2',
    'Rack_Gesamtansicht',
  ],
  defaultStorageTargets: [
    {
      id: 'mydrive',
      type: 'onedrive_personal',
      label: 'Eigenes OneDrive',
      icon: '📱',
      subtitle: 'Persoenlicher Cloud-Speicher',
      configurable: { basePath: '/test' },
    },
  ],
  defaultStorageTargetId: 'mydrive',
};

const TENANT_FILE_OVERRIDE_SUFFIX = '-tenant.json';

function normalizeArray(value) {
  return Array.isArray(value) ? value : [];
}

function loadTenantFileOverride(tenantId) {
  const id = toStr(tenantId);
  if (!id) return null;

  const candidates = [
    path.join(__dirname, `${id}${TENANT_FILE_OVERRIDE_SUFFIX}`),
    path.join(__dirname, 'tenant-overrides', `${id}.json`),
  ];

  for (const filePath of candidates) {
    if (!fs.existsSync(filePath)) continue;

    try {
      const raw = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
      if (!raw || typeof raw !== 'object') continue;

      const overrideTenantId = toStr(raw.tenantId) || id;
      if (overrideTenantId !== id) {
        console.warn(`Skipping tenant override ${filePath}: tenantId mismatch (${overrideTenantId} !== ${id})`);
        continue;
      }

      return {
        ...raw,
        tenantId: id,
      };
    } catch (err) {
      console.warn(`Failed to read tenant override ${filePath}: ${err.message}`);
    }
  }

  return null;
}

function applyTenantFileOverride(baseConfig, tenantId, opts = {}) {
  const override = loadTenantFileOverride(tenantId);
  if (!override) return baseConfig;

  const merged = deepMerge(baseConfig && typeof baseConfig === 'object' ? baseConfig : {}, override);
  merged.tenantId = toStr(tenantId);
  if (!merged.createdAt) merged.createdAt = nowIso();
  merged.updatedAt = nowIso();

  if (opts && opts.sourceCompanyId && !toStr(merged.sourceCompanyId)) {
    merged.sourceCompanyId = toStr(opts.sourceCompanyId);
  }
  if (opts && toStr(opts.managedBy)) {
    merged.managedBy = toStr(opts.managedBy);
  }

  return merged;
}

function syncCompanyConfigFromTenantOverride(company, tenantOverride) {
  if (!company || !tenantOverride || typeof tenantOverride !== 'object') return;

  const nextConfig = normalizeCompanyConfig(company.config);

  const overrideFields = normalizeArray(tenantOverride.fields)
    .filter((field) => field && typeof field === 'object' && toStr(field.key));
  if (overrideFields.length) {
    nextConfig.fields = overrideFields.map((field) => ({
      key: toStr(field.key),
      type: toStr(field.type) || 'text',
      label: toStr(field.label) || inferFieldLabel(toStr(field.key)),
      required: toBool(field.required, false),
      options: normalizeArray(field.options).map((item) => toStr(item)).filter(Boolean),
      placeholder: toStr(field.placeholder),
    }));
  }

  const templates = normalizeArray(tenantOverride.templates);
  const defaultTemplateId = toStr(tenantOverride.defaultTemplateId);
  const template = templates.find((item) => toStr(item && item.templateId) === defaultTemplateId) || templates[0] || null;

  if (template) {
    const folderPattern = toStr(template.folderPattern);
    if (folderPattern) nextConfig.folderNamingTemplate = folderPattern;

    const fileNamePattern = toStr(template.fileNamePattern);
    if (fileNamePattern) nextConfig.fileNamingTemplate = fileNamePattern;

    const photoVariables = normalizeArray(template.captureSteps)
      .map((step) => toStr(step && step.label))
      .filter(Boolean);
    if (photoVariables.length) {
      nextConfig.photoVariables = photoVariables;
    }

    nextConfig.dropdownPhotoVariables = normalizeDropdownPhotoVariables(
      template.dropdownPhotoVariables,
      nextConfig.fields
    );
  }

  company.config = nextConfig;
}

function refreshTenantConfigFromOverride(tenantId, opts = {}) {
  const id = toStr(tenantId);
  if (!id) return { config: null, changed: false };

  const override = loadTenantFileOverride(id);
  if (!override) {
    return { config: data.tenantConfigs[id] || null, changed: false };
  }

  const existing = data.tenantConfigs[id] || null;
  const baseConfig = existing || {
    tenantId: id,
    name: toStr(override.name) || id,
    createdAt: nowIso(),
    updatedAt: nowIso(),
  };

  const merged = applyTenantFileOverride(baseConfig, id, opts);
  const changed = JSON.stringify(existing) !== JSON.stringify(merged);

  if (changed || !existing) {
    data.tenantConfigs[id] = merged;
    if (opts.persist !== false) saveData();
    return { config: merged, changed: true };
  }

  return { config: existing, changed: false };
}

function slugify(value) {
  return toStr(value)
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-zA-Z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .toLowerCase();
}

function inferFieldLabel(key) {
  const map = {
    city: 'Stadt',
    siteId: 'Standort-ID',
    netElement: 'Netzelementnummer',
    project: 'Projektnummer',
    popId: 'POP ID',
    popType: 'POP Typ',
    date: 'Datum',
  };
  return map[key] || key;
}

function inferFieldsFromTemplate(template) {
  const tokens = [...new Set((toStr(template).match(/\{([^}]+)\}/g) || [])
    .map((token) => token.replace(/[{}]/g, '').trim())
    .filter(Boolean))];

  if (!tokens.length) return [...PLATFORM_DEFAULTS.defaultFields];

  return tokens.map((token) => ({
    key: token,
    type: token === 'date' ? 'date' : 'text',
    label: inferFieldLabel(token),
    required: token === 'city' || token === 'siteId' || token === 'popId' || token === 'popType',
  }));
}

function normalizeInputFieldType(type) {
  const normalized = toStr(type).toLowerCase();
  if (normalized === 'dropdown' || normalized === 'date' || normalized === 'text' || normalized === 'number') {
    return normalized;
  }
  return 'text';
}

const SUPPORTED_FIELD_TYPES = new Set(['text', 'number', 'dropdown', 'date']);

function validateFieldTypes(fields, pathPrefix = 'fields') {
  const errors = [];
  const entries = normalizeArray(fields);

  entries.forEach((field, index) => {
    if (!field || typeof field !== 'object') {
      errors.push({ path: `${pathPrefix}[${index}]`, message: 'Field must be an object' });
      return;
    }

    const key = toStr(field.key);
    if (!key) {
      errors.push({ path: `${pathPrefix}[${index}].key`, message: 'Field key is required' });
    }

    const rawType = toStr(field.type).toLowerCase();
    if (rawType && !SUPPORTED_FIELD_TYPES.has(rawType)) {
      errors.push({
        path: `${pathPrefix}[${index}].type`,
        message: `Unsupported field type: ${rawType}`,
        allowed: [...SUPPORTED_FIELD_TYPES],
      });
    }
  });

  return errors;
}

function validateStorageTargets(storageTargets, defaultStorageTargetId, pathPrefix = 'storageTargets') {
  const errors = [];
  const entries = normalizeArray(storageTargets)
    .filter((item) => item && typeof item === 'object')
    .map((item, index) => ({ item, index }));

  const ids = [];
  entries.forEach(({ item, index }) => {
    const id = toStr(item.id);
    if (!id) {
      errors.push({ path: `${pathPrefix}[${index}].id`, message: 'Storage target id is required' });
      return;
    }
    ids.push(id);
  });

  const duplicates = ids.filter((id, index) => ids.indexOf(id) !== index);
  if (duplicates.length) {
    errors.push({ path: pathPrefix, message: `Duplicate storage target ids: ${[...new Set(duplicates)].join(', ')}` });
  }

  const defaultId = toStr(defaultStorageTargetId);
  if (defaultId && ids.length && !ids.includes(defaultId)) {
    errors.push({
      path: 'defaultStorageTargetId',
      message: `defaultStorageTargetId '${defaultId}' not found in storageTargets`,
    });
  }

  return errors;
}

function validatePatternCompatibility(pattern, fields, allowPhotoVar, path, errors) {
  const configuredPattern = toStr(pattern);
  if (!configuredPattern) return;

  const normalizedFields = normalizeArray(fields);
  if (!normalizedFields.length) return;

  if (!isPatternCompatibleWithFields(configuredPattern, normalizedFields, allowPhotoVar)) {
    errors.push({
      path,
      message: `Pattern '${configuredPattern}' contains tokens that are not present in fields`,
      tokens: extractPatternTokens(configuredPattern),
    });
  }
}

function validateCompanyConfigInput(config) {
  const errors = [];
  const source = config && typeof config === 'object' ? config : {};
  const fields = normalizeArray(source.fields);

  errors.push(...validateFieldTypes(fields, 'config.fields'));
  errors.push(...validateStorageTargets(source.uploadTargets, null, 'config.uploadTargets'));
  validatePatternCompatibility(source.folderNamingTemplate || source.folderPattern, fields, false, 'config.folderNamingTemplate', errors);
  validatePatternCompatibility(source.fileNamingTemplate || source.fileNamePattern, fields, true, 'config.fileNamingTemplate', errors);

  return errors;
}

function validateTenantPayloadInput(payload, fallback) {
  const errors = [];
  const source = payload && typeof payload === 'object' ? payload : {};
  const merged = {
    ...(fallback && typeof fallback === 'object' ? fallback : {}),
    ...source,
  };

  const fields = normalizeArray(merged.fields);
  errors.push(...validateFieldTypes(fields, 'tenant.fields'));

  const templates = normalizeArray(merged.templates)
    .filter((tpl) => tpl && typeof tpl === 'object');

  templates.forEach((tpl, index) => {
    validatePatternCompatibility(tpl.folderPattern, fields, false, `tenant.templates[${index}].folderPattern`, errors);
    validatePatternCompatibility(tpl.fileNamePattern, fields, true, `tenant.templates[${index}].fileNamePattern`, errors);
  });

  validatePatternCompatibility(merged.folderPattern, fields, false, 'tenant.folderPattern', errors);
  validatePatternCompatibility(merged.fileNamePattern, fields, true, 'tenant.fileNamePattern', errors);
  errors.push(...validateStorageTargets(merged.storageTargets, merged.defaultStorageTargetId, 'tenant.storageTargets'));

  return errors;
}

function validationError(res, details) {
  return res.status(400).json({
    error: 'Validation failed',
    details,
  });
}

function normalizeTenantFields(fields, folderNamingTemplate) {
  const rawFields = normalizeArray(fields)
    .filter((item) => item && typeof item === 'object' && toStr(item.key));

  if (!rawFields.length) {
    return inferFieldsFromTemplate(folderNamingTemplate);
  }

  return rawFields.map((field) => {
    const key = toStr(field.key);
    const type = normalizeInputFieldType(field.type);
    const label = toStr(field.label) || inferFieldLabel(key);
    const required = toBool(field.required, false);
    const placeholder = toStr(field.placeholder);

    const out = {
      key,
      type,
      label,
      required,
    };

    if (type === 'dropdown') {
      out.options = toStringList(field.options);
    }
    if (placeholder) {
      out.placeholder = placeholder;
    }

    return out;
  });
}

function toStringList(value) {
  if (Array.isArray(value)) {
    return [...new Set(value.map((item) => toStr(item)).filter(Boolean))];
  }

  const text = toStr(value);
  if (!text) return [];

  return [...new Set(text
    .split(',')
    .map((item) => toStr(item))
    .filter(Boolean))];
}

function normalizeDropdownPhotoVariables(rawMap, fields) {
  const source = rawMap && typeof rawMap === 'object' && !Array.isArray(rawMap)
    ? rawMap
    : {};
  const dropdownFields = normalizeArray(fields)
    .filter((item) => item && typeof item === 'object')
    .map((item) => ({
      key: toStr(item.key),
      type: toStr(item.type).toLowerCase(),
      options: toStringList(item.options),
    }))
    .filter((item) => item.key && item.type === 'dropdown');

  const fieldByKey = new Map(dropdownFields.map((item) => [item.key, item]));
  const out = {};

  for (const [fieldKeyRaw, optionMapRaw] of Object.entries(source)) {
    const fieldKey = toStr(fieldKeyRaw);
    if (!fieldKey || !fieldByKey.has(fieldKey)) continue;

    if (!optionMapRaw || typeof optionMapRaw !== 'object' || Array.isArray(optionMapRaw)) continue;
    const allowedOptions = new Set(fieldByKey.get(fieldKey).options);
    const normalizedOptionMap = {};

    for (const [optionRaw, varsRaw] of Object.entries(optionMapRaw)) {
      const option = toStr(optionRaw);
      if (!option) continue;
      if (allowedOptions.size > 0 && !allowedOptions.has(option)) continue;

      const values = toStringList(varsRaw);
      if (values.length) {
        normalizedOptionMap[option] = values;
      }
    }

    if (Object.keys(normalizedOptionMap).length) {
      out[fieldKey] = normalizedOptionMap;
    }
  }

  return out;
}

function normalizeCompanyConfig(config) {
  const source = config && typeof config === 'object' ? { ...config } : {};
  const folderNamingTemplate =
    toStr(source.folderNamingTemplate || source.folderPattern) ||
    PLATFORM_DEFAULTS.defaultFolderNamingTemplate;
  const fileNamingTemplate =
    toStr(source.fileNamingTemplate || source.fileNamePattern) ||
    PLATFORM_DEFAULTS.defaultFileNamingTemplate;

  const resolvedFields = normalizeTenantFields(source.fields, folderNamingTemplate);
  const photoVariables = normalizeArray(source.photoVariables)
    .map((item) => toStr(item))
    .filter(Boolean);
  const uploadTargets = normalizeArray(source.uploadTargets).filter((item) => item && typeof item === 'object');
  const dropdownPhotoVariables = normalizeDropdownPhotoVariables(source.dropdownPhotoVariables, resolvedFields);

  return {
    ...source,
    folderNamingTemplate,
    fileNamingTemplate,
    fields: resolvedFields,
    photoVariables: photoVariables.length ? photoVariables : [...PLATFORM_DEFAULTS.defaultPhotoVariables],
    dropdownPhotoVariables,
    uploadTargets: uploadTargets.length ? uploadTargets : [...PLATFORM_DEFAULTS.defaultStorageTargets],
  };
}

function normalizeCaptureSteps(steps) {
  const normalized = normalizeArray(steps)
    .filter((item) => item && typeof item === 'object')
    .map((step, index) => {
      const label = toStr(step.label) || toStr(step.id) || `Step ${index + 1}`;
      const id = toStr(step.id) || slugify(label) || `step_${index + 1}`;
      const orderRaw = Number(step.order);

      return {
        id,
        label,
        translationKey: toStr(step.translationKey) || `photo_${id}`,
        required: toBool(step.required, false),
        order: Number.isFinite(orderRaw) && orderRaw > 0 ? orderRaw : index + 1,
      };
    })
    .sort((a, b) => a.order - b.order);

  return normalized.map((step, index) => ({
    ...step,
    order: index + 1,
  }));
}

function normalizePatternToken(value) {
  return toStr(value)
    .replace(/[{}]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');
}

function extractPatternTokens(pattern) {
  return [...new Set((toStr(pattern).match(/\{([^}]+)\}/g) || [])
    .map((token) => token.replace(/[{}]/g, '').trim())
    .filter(Boolean))];
}

function buildFolderPatternFromFields(fields) {
  const keys = normalizeArray(fields)
    .map((field) => toStr(field && field.key))
    .filter(Boolean);
  if (!keys.length) return PLATFORM_DEFAULTS.defaultFolderNamingTemplate;
  return keys.map((key) => `{${key}}`).join(' ');
}

function buildFilePatternFromFields(fields) {
  const keys = normalizeArray(fields)
    .map((field) => toStr(field && field.key))
    .filter(Boolean);
  if (!keys.length) return PLATFORM_DEFAULTS.defaultFileNamingTemplate;
  return `${keys.map((key) => `{${key}}`).join('_')}` + '_{photoVar}.jpg';
}

function isPatternCompatibleWithFields(pattern, fields, allowPhotoVar = false) {
  const tokens = extractPatternTokens(pattern);
  if (!tokens.length) return false;

  const fieldTokenSet = new Set(normalizeArray(fields)
    .map((field) => normalizePatternToken(field && field.key))
    .filter(Boolean));

  const relevant = tokens
    .map((token) => normalizePatternToken(token))
    .filter((token) => token && (!allowPhotoVar || token !== 'photovar'));

  if (!relevant.length) return false;
  return relevant.every((token) => fieldTokenSet.has(token));
}

function normalizeTenantConfigForResponse(config) {
  if (!config || typeof config !== 'object') return null;

  const defaultFolderPattern =
    toStr(config.folderPattern) ||
    toStr(config.defaultFolderNamingTemplate) ||
    PLATFORM_DEFAULTS.defaultFolderNamingTemplate;

  const fields = normalizeTenantFields(config.fields, defaultFolderPattern);

  const templates = normalizeArray(config.templates)
    .filter((tpl) => tpl && typeof tpl === 'object')
    .map((tpl, index) => {
      const templateId = toStr(tpl.templateId) || `template_${index + 1}`;
      const name = toStr(tpl.name) || templateId;
      const configuredFolderPattern = toStr(tpl.folderPattern) || defaultFolderPattern;
      const configuredFileNamePattern = toStr(tpl.fileNamePattern) || PLATFORM_DEFAULTS.defaultFileNamingTemplate;
      const folderPattern = isPatternCompatibleWithFields(configuredFolderPattern, fields)
        ? configuredFolderPattern
        : buildFolderPatternFromFields(fields);
      const fileNamePattern = isPatternCompatibleWithFields(configuredFileNamePattern, fields, true)
        ? configuredFileNamePattern
        : buildFilePatternFromFields(fields);
      const captureSteps = normalizeCaptureSteps(tpl.captureSteps);

      return {
        ...tpl,
        templateId,
        name,
        folderPattern,
        fileNamePattern,
        captureSteps,
        dropdownPhotoVariables: normalizeDropdownPhotoVariables(tpl.dropdownPhotoVariables, fields),
      };
    });

  return {
    ...config,
    fields,
    templates,
  };
}

function toTenantStorageTarget(target, index) {
  const id = toStr(target.id) || `target-${index + 1}`;
  const type = toStr(target.type) || 'onedrive_personal';
  const config = target && typeof target.config === 'object' ? target.config : {};

  const out = {
    id,
    type,
    label: toStr(target.label || target.name) || id,
    icon: toStr(target.icon) || '☁️',
    subtitle: toStr(target.subtitle || target.name) || '',
  };

  if (toStr(config.basePath)) {
    out.configurable = { basePath: toStr(config.basePath) };
  }
  if (toStr(config.driveId)) out.driveId = toStr(config.driveId);
  if (toStr(config.itemId)) out.itemId = toStr(config.itemId);
  if (toStr(config.subPath)) out.subPath = toStr(config.subPath);
  if (toStr(config.appFolder)) out.appFolder = toStr(config.appFolder);

  return out;
}

function toCaptureSteps(photoVariables) {
  return photoVariables.map((label, index) => {
    const normalized = toStr(label);
    const stepId = slugify(normalized) || `step_${index + 1}`;
    return {
      id: stepId,
      label: normalized,
      translationKey: `photo_${stepId}`,
      required: index < 3,
      order: index + 1,
    };
  });
}

function buildTenantConfigFromCompany(company, existingTenantConfig) {
  const companyConfig = normalizeCompanyConfig(company.config);
  const tenantId = toStr(company.tenantId) || company.id;
  const templateId = `${company.id}_default`;

  const tenantStorageTargets = normalizeArray(companyConfig.uploadTargets)
    .map(toTenantStorageTarget)
    .filter((item) => item && item.id);

  const storageTargets = tenantStorageTargets.length
    ? tenantStorageTargets
    : normalizeArray(existingTenantConfig && existingTenantConfig.storageTargets).length
      ? normalizeArray(existingTenantConfig.storageTargets)
      : [...PLATFORM_DEFAULTS.defaultStorageTargets];

  const generatedTemplate = {
    templateId,
    name: `${company.name} Standard`,
    folderPattern: companyConfig.folderNamingTemplate,
    fileNamePattern: companyConfig.fileNamingTemplate,
    captureSteps: toCaptureSteps(companyConfig.photoVariables),
    dropdownPhotoVariables: normalizeDropdownPhotoVariables(
      companyConfig.dropdownPhotoVariables,
      companyConfig.fields
    ),
  };

  const templates = normalizeArray(existingTenantConfig && existingTenantConfig.templates)
    .filter((tpl) => toStr(tpl && tpl.templateId) !== templateId);
  templates.unshift(generatedTemplate);

  return {
    ...(existingTenantConfig && typeof existingTenantConfig === 'object' ? existingTenantConfig : {}),
    tenantId,
    name: toStr(company.name) || tenantId,
    sourceCompanyId: company.id,
    managedBy: 'company-sync',
    fields: normalizeArray(companyConfig.fields),
    defaultStorageTargetId: toStr(existingTenantConfig && existingTenantConfig.defaultStorageTargetId) || storageTargets[0].id || PLATFORM_DEFAULTS.defaultStorageTargetId,
    storageTargets,
    defaultTemplateId: templateId,
    templates,
    updatedAt: nowIso(),
    createdAt: (existingTenantConfig && existingTenantConfig.createdAt) || nowIso(),
  };
}

function normalizeCompany(raw) {
  const id = toStr(raw.id);
  return {
    id,
    name: toStr(raw.name),
    domain: toStr(raw.domain).toLowerCase(),
    tenantId: toStr(raw.tenantId) || id,
    isActive: toBool(raw.isActive, true),
    config: normalizeCompanyConfig(raw && raw.config),
    createdAt: raw.createdAt || nowIso(),
    updatedAt: raw.updatedAt || raw.createdAt || nowIso(),
  };
}

function normalizeUser(raw) {
  const email = toLowerEmail(raw.email);
  return {
    email,
    name: toStr(raw.name),
    companyId: toStr(raw.companyId) || null,
    role: toStr(raw.role) || 'user',
    isActive: toBool(raw.isActive, true),
    createdAt: raw.createdAt || nowIso(),
    updatedAt: raw.updatedAt || raw.createdAt || nowIso(),
  };
}

function normalizeDevice(raw, deviceId, companies) {
  const companyId = toStr(raw.companyId) || null;
  const tenantId = toStr(raw.tenantId) || (companyId && companies[companyId] ? companies[companyId].tenantId : null);
  return {
    deviceId,
    allowed: toBool(raw.allowed, true),
    message: toStr(raw.message),
    graceUntil: raw.graceUntil || null,
    createdAt: raw.createdAt || nowIso(),
    updatedAt: raw.updatedAt || raw.createdAt || nowIso(),
    lastSeen: raw.lastSeen || raw.updatedAt || raw.createdAt || nowIso(),
    platform: toStr(raw.platform) || 'unknown',
    appVersion: Number.isFinite(Number(raw.appVersion)) ? Number(raw.appVersion) : 0,
    companyId,
    tenantId,
    userEmail: toLowerEmail(raw.userEmail) || null,
    lastSeenEmail: toLowerEmail(raw.lastSeenEmail) || null,
    installationId: toStr(raw.installationId) || null,
    fingerprintHash: toStr(raw.fingerprintHash) || null,
    assignmentStatus: toStr(raw.assignmentStatus) || (companyId ? 'assigned' : 'unassigned'),
    assignmentUpdatedAt: raw.assignmentUpdatedAt || null,
    assignmentUpdatedBy: toStr(raw.assignmentUpdatedBy) || null,
  };
}

function normalizeData(raw) {
  const base = raw && typeof raw === 'object' ? raw : {};
  const out = defaultData();

  out.debugMode = toBool(base.debugMode, false);
  out.defaultTenantId = toStr(base.defaultTenantId) || 'gravit_default';
  out.manualTenantId = toStr(base.manualTenantId);

  if (base.domainTenantMapping && typeof base.domainTenantMapping === 'object') {
    for (const [domain, tenantId] of Object.entries(base.domainTenantMapping)) {
      const d = toStr(domain).toLowerCase();
      const t = toStr(tenantId);
      if (d && t) out.domainTenantMapping[d] = t;
    }
  }

  if (base.companies && typeof base.companies === 'object') {
    for (const [id, company] of Object.entries(base.companies)) {
      const normalized = normalizeCompany({ ...(company || {}), id: toStr((company || {}).id) || toStr(id) });
      if (normalized.id) out.companies[normalized.id] = normalized;
    }
  }

  if (base.users && typeof base.users === 'object') {
    for (const [email, user] of Object.entries(base.users)) {
      const normalized = normalizeUser({ ...(user || {}), email: toLowerEmail((user || {}).email) || toLowerEmail(email) });
      if (normalized.email) out.users[normalized.email] = normalized;
    }
  }

  if (base.devices && typeof base.devices === 'object') {
    for (const [deviceId, device] of Object.entries(base.devices)) {
      const id = toStr((device || {}).deviceId) || toStr(deviceId);
      if (!id) continue;
      out.devices[id] = normalizeDevice(device || {}, id, out.companies);
    }
  }

  if (base.deviceAliases && typeof base.deviceAliases === 'object') {
    for (const [aliasId, canonicalId] of Object.entries(base.deviceAliases)) {
      const alias = toStr(aliasId);
      const canonical = toStr(canonicalId);
      if (!alias || !canonical || alias === canonical) continue;
      out.deviceAliases[alias] = canonical;
    }
  }

  if (base.tenantConfigs && typeof base.tenantConfigs === 'object') {
    for (const [tenantId, cfg] of Object.entries(base.tenantConfigs)) {
      const tid = toStr((cfg || {}).tenantId) || toStr(tenantId);
      if (!tid) continue;
      out.tenantConfigs[tid] = {
        ...(cfg || {}),
        tenantId: tid,
        createdAt: (cfg || {}).createdAt || nowIso(),
        updatedAt: (cfg || {}).updatedAt || (cfg || {}).createdAt || nowIso(),
      };
    }
  }

  const assignments = Array.isArray(base.assignments) ? base.assignments : [];
  out.assignments = assignments
    .map((item) => ({
      ts: item && item.ts ? item.ts : nowIso(),
      action: toStr(item && item.action) || 'assign',
      actor: toStr(item && item.actor) || 'admin',
      deviceId: toStr(item && item.deviceId),
      fromCompanyId: toStr(item && item.fromCompanyId) || null,
      toCompanyId: toStr(item && item.toCompanyId) || null,
      fromUserEmail: toLowerEmail(item && item.fromUserEmail) || null,
      toUserEmail: toLowerEmail(item && item.toUserEmail) || null,
      fromTenantId: toStr(item && item.fromTenantId) || null,
      toTenantId: toStr(item && item.toTenantId) || null,
    }))
    .filter((item) => item.deviceId);

  return out;
}

function buildEmailTenantMapping() {
  const mapping = {};

  for (const user of Object.values(data.users || {})) {
    if (!user || !user.email || !user.companyId) continue;
    const company = data.companies[user.companyId];
    if (!company || !company.isActive) continue;
    const tenantId = toStr(company.tenantId) || company.id;
    if (tenantId) {
      mapping[toLowerEmail(user.email)] = tenantId;
    }
  }

  return mapping;
}

function isDebugModeEnabled() {
  return toBool(data && data.debugMode, false);
}

function debugLog(...args) {
  if (!isDebugModeEnabled()) return;
  console.log('[DEBUG]', ...args);
}

function syncCompanyDerivedState(company) {
  if (!company || !company.id) return;

  company.config = normalizeCompanyConfig(company.config);
  const tenantId = toStr(company.tenantId) || company.id;
  company.tenantId = tenantId;

  const tenantOverride = loadTenantFileOverride(tenantId);
  if (tenantOverride) {
    syncCompanyConfigFromTenantOverride(company, tenantOverride);
  }

  const existingTenant = data.tenantConfigs[tenantId];
  const generatedTenantConfig = buildTenantConfigFromCompany(company, existingTenant);
  data.tenantConfigs[tenantId] = applyTenantFileOverride(generatedTenantConfig, tenantId, {
    sourceCompanyId: company.id,
    managedBy: 'company-sync+file-override',
  });

  if (company.domain) {
    const domain = toStr(company.domain).toLowerCase();
    if (!data.domainTenantMapping[domain] || data.domainTenantMapping[domain] === tenantId) {
      data.domainTenantMapping[domain] = tenantId;
    }
  }

  for (const device of Object.values(data.devices)) {
    if (device.companyId === company.id) {
      device.tenantId = tenantId;
    }
  }
}

function ensureModelConsistency() {
  if (!data.deviceAliases || typeof data.deviceAliases !== 'object') {
    data.deviceAliases = {};
  }

  for (const [aliasId, canonicalId] of Object.entries(data.deviceAliases)) {
    const alias = toStr(aliasId);
    const canonical = resolveCanonicalDeviceId(canonicalId);
    if (!alias || !canonical || alias === canonical || !data.devices[canonical]) {
      delete data.deviceAliases[aliasId];
      continue;
    }
    data.deviceAliases[alias] = canonical;
  }

  const fingerprintSeen = {};
  for (const device of Object.values(data.devices || {})) {
    const fingerprint = toStr(device && device.fingerprintHash);
    if (!fingerprint) continue;

    if (!fingerprintSeen[fingerprint]) {
      fingerprintSeen[fingerprint] = device;
      continue;
    }

    const existing = fingerprintSeen[fingerprint];
    const canonical = chooseCanonicalDevice(existing, device);
    const duplicate = canonical.deviceId === existing.deviceId ? device : existing;

    debugLog('Consistency merge for duplicate fingerprint', {
      fingerprintHash: fingerprint,
      canonicalDeviceId: canonical.deviceId,
      duplicateDeviceId: duplicate.deviceId,
      canonicalCompanyId: canonical.companyId || null,
      duplicateCompanyId: duplicate.companyId || null,
    });

    mergeDeviceRecords(canonical, duplicate);
    delete data.devices[duplicate.deviceId];
    rewriteAliasesTarget(duplicate.deviceId, canonical.deviceId);
    fingerprintSeen[fingerprint] = canonical;
  }

  for (const company of Object.values(data.companies || {})) {
    syncCompanyDerivedState(company);
  }

  for (const device of Object.values(data.devices || {})) {
    const effectiveEmail = toLowerEmail(device.userEmail || device.lastSeenEmail) || null;
    if (effectiveEmail) {
      device.userEmail = effectiveEmail;

      if (!data.users[effectiveEmail] && device.companyId) {
        data.users[effectiveEmail] = normalizeUser({
          email: effectiveEmail,
          name: '',
          role: 'user',
          isActive: true,
          companyId: device.companyId,
        });
      }

      const user = data.users[effectiveEmail];
      if (user && user.companyId) {
        device.companyId = user.companyId;
        device.tenantId = resolveCompanyTenantId(user.companyId);
        device.assignmentStatus = 'assigned';
      }
    }

    if (device.companyId && !device.tenantId) {
      device.tenantId = resolveCompanyTenantId(device.companyId);
    }
  }
}

function cleanupDeviceAliases({ dryRun = true } = {}) {
  const aliases = data.deviceAliases && typeof data.deviceAliases === 'object'
    ? data.deviceAliases
    : {};
  const initialCount = Object.keys(aliases).length;

  const removed = [];
  const seenAliases = new Set();

  for (const [aliasId, mappedId] of Object.entries(aliases)) {
    const alias = toStr(aliasId);
    const mapped = toStr(mappedId);
    const canonical = resolveCanonicalDeviceId(mapped);

    const invalid =
      !alias ||
      !mapped ||
      alias === mapped ||
      alias === canonical ||
      !canonical ||
      !data.devices[canonical] ||
      seenAliases.has(alias);

    if (invalid) {
      removed.push({ aliasId: alias, mappedId: mapped, canonicalId: canonical || null });
      continue;
    }

    seenAliases.add(alias);
  }

  if (!dryRun) {
    for (const item of removed) {
      delete aliases[item.aliasId];
    }
    data.deviceAliases = aliases;
  }

  return {
    dryRun,
    removedCount: removed.length,
    removed,
    remainingCount: dryRun ? initialCount - removed.length : Object.keys(aliases).length,
  };
}

function loadData() {
  try {
    if (!fs.existsSync(DATA_FILE)) {
      ensureDirForFile(DATA_FILE);
      const seed = defaultData();
      fs.writeFileSync(DATA_FILE, JSON.stringify(seed, null, 2));
      return seed;
    }

    const raw = fs.readFileSync(DATA_FILE, 'utf-8');
    const parsed = JSON.parse(raw);
    return normalizeData(parsed);
  } catch (err) {
    console.error('Error loading data:', err.message);
    return defaultData();
  }
}

let data = loadData();
ensureModelConsistency();
saveData();

function saveData() {
  try {
    ensureDirForFile(DATA_FILE);
    const tempFile = `${DATA_FILE}.tmp`;
    createDataBackupSnapshot();
    fs.writeFileSync(tempFile, JSON.stringify(data, null, 2));
    fs.renameSync(tempFile, DATA_FILE);
    return true;
  } catch (err) {
    console.error('Error saving data:', err.message);
    return false;
  }
}

function computeGraceActive(device) {
  if (!device || !device.graceUntil) return false;
  const until = new Date(device.graceUntil).getTime();
  if (!Number.isFinite(until)) return false;
  return until > Date.now();
}

function computeEffectiveAllowed(device) {
  if (!device) return false;
  if (device.allowed === true) return true;
  return computeGraceActive(device);
}

function computeAssignmentStateVersion(device) {
  if (!device) return 'none';
  return [
    toStr(device.assignmentUpdatedAt || ''),
    toStr(device.companyId || ''),
    toStr(device.tenantId || ''),
    toStr(device.assignmentStatus || ''),
  ].join('|');
}

function computeConfigStateVersion(company, effectiveTenantConfig) {
  const companyUpdated = toStr(company && company.updatedAt);
  const tenantUpdated = toStr(effectiveTenantConfig && effectiveTenantConfig.updatedAt);
  return [companyUpdated, tenantUpdated].join('|');
}

function readDeviceMeta(req) {
  const query = req.query || {};
  const body = req.body || {};
  const headers = req.headers || {};

  const platform = toStr(query.platform || body.platform) || null;
  const appVersionRaw = toStr(query.appVersion || body.appVersion);
  const appVersion = Number.isFinite(Number(appVersionRaw)) ? Number(appVersionRaw) : null;

  return {
    platform,
    appVersion,
    installationId: toStr(query.installationId || body.installationId || headers['x-installation-id']) || null,
    fingerprintHash: toStr(query.fingerprintHash || body.fingerprintHash || headers['x-device-fingerprint']) || null,
    assignmentStateVersion:
      toStr(query.assignmentStateVersion || body.assignmentStateVersion || headers['x-assignment-state-version']) || null,
    userEmail:
      toLowerEmail(
        query.userEmail ||
          body.userEmail ||
          query.email ||
          body.email ||
          query.upn ||
          body.upn ||
          headers['x-user-email'],
      ) || null,
  };
}

function getOrCreateDevice(deviceId, req) {
  const requestedId = toStr(deviceId);
  const meta = readDeviceMeta(req);
  const now = nowIso();

  let device = data.devices[resolveCanonicalDeviceId(requestedId)] || null;

  if (!device && meta.fingerprintHash) {
    const byFingerprint = Object.values(data.devices).find(
      (candidate) => candidate && toStr(candidate.fingerprintHash) === toStr(meta.fingerprintHash),
    );
    if (byFingerprint) {
      device = byFingerprint;
      setDeviceAlias(requestedId, byFingerprint.deviceId);
      debugLog('Resolved device via fingerprintHash', {
        requestedId,
        canonicalDeviceId: byFingerprint.deviceId,
        fingerprintHash: toStr(meta.fingerprintHash),
      });
    }
  }

  if (!device && meta.installationId) {
    const byInstallation = Object.values(data.devices).find(
      (candidate) => candidate && toStr(candidate.installationId) === toStr(meta.installationId),
    );
    if (byInstallation) {
      device = byInstallation;
      setDeviceAlias(requestedId, byInstallation.deviceId);
      debugLog('Resolved device via installationId', {
        requestedId,
        canonicalDeviceId: byInstallation.deviceId,
        installationId: toStr(meta.installationId),
      });
    }
  }

  if (!device) {
    device = normalizeDevice(
      {
        deviceId: requestedId,
        allowed: true,
        companyId: null,
        tenantId: null,
        userEmail: null,
        assignmentStatus: 'unassigned',
      },
      requestedId,
      data.companies,
    );
    device.createdAt = now;
    device.lastSeen = now;
    data.devices[requestedId] = device;
    console.log(`New device registered: ${requestedId}`);
  } else if (requestedId && requestedId !== device.deviceId) {
    setDeviceAlias(requestedId, device.deviceId);
  }

  // Prefer deterministic app-side IDs once fingerprint is available.
  if (
    meta.fingerprintHash &&
    requestedId &&
    requestedId.startsWith('dev_') &&
    requestedId !== device.deviceId
  ) {
    const oldId = device.deviceId;
    if (!data.devices[requestedId]) {
      delete data.devices[oldId];
      device.deviceId = requestedId;
      data.devices[requestedId] = device;
      rewriteAliasesTarget(oldId, requestedId);
      debugLog('Promoted canonical deviceId to deterministic value', {
        oldId,
        newId: requestedId,
        reason: 'deterministic-app-id',
      });
    }
  }

  // Collapse any duplicate records that share the same stable fingerprint.
  if (meta.fingerprintHash) {
    const duplicate = Object.values(data.devices).find(
      (candidate) =>
        candidate &&
        toStr(candidate.deviceId) !== toStr(device.deviceId) &&
        toStr(candidate.fingerprintHash) === toStr(meta.fingerprintHash),
    );
    if (duplicate) {
      const canonical = chooseCanonicalDevice(device, duplicate);
      const toRemove = canonical.deviceId === device.deviceId ? duplicate : device;
      debugLog('Merging duplicate devices by fingerprint', {
        requestedId,
        fingerprintHash: toStr(meta.fingerprintHash),
        canonicalDeviceId: canonical.deviceId,
        duplicateDeviceId: toRemove.deviceId,
        canonicalCompanyId: canonical.companyId || null,
        duplicateCompanyId: toRemove.companyId || null,
      });
      mergeDeviceRecords(canonical, toRemove);
      delete data.devices[toRemove.deviceId];
      rewriteAliasesTarget(toRemove.deviceId, canonical.deviceId);
      if (requestedId && requestedId !== canonical.deviceId) {
        setDeviceAlias(requestedId, canonical.deviceId);
      }
      device = canonical;
    }
  }

  device.lastSeen = now;
  device.updatedAt = now;

  if (meta.platform) device.platform = meta.platform;
  if (meta.appVersion !== null) device.appVersion = meta.appVersion;
  if (meta.installationId) device.installationId = meta.installationId;
  if (meta.fingerprintHash) device.fingerprintHash = meta.fingerprintHash;
  let effectiveUserEmail = meta.userEmail;
  if (!effectiveUserEmail && meta.installationId) {
    const siblingDevice = Object.values(data.devices).find(
      (candidate) =>
        candidate &&
        toStr(candidate.deviceId) !== device.deviceId &&
        toStr(candidate.installationId) === meta.installationId &&
        toLowerEmail(candidate.userEmail || candidate.lastSeenEmail),
    );
    effectiveUserEmail = siblingDevice
      ? toLowerEmail(siblingDevice.userEmail || siblingDevice.lastSeenEmail)
      : null;

    if (effectiveUserEmail) {
      debugLog('Derived userEmail from installationId', {
        deviceId: device.deviceId,
        installationId: meta.installationId,
        userEmail: effectiveUserEmail,
        sourceDeviceId: siblingDevice.deviceId,
      });
    }
  }

  if (effectiveUserEmail) {
    debugLog('Device meta contains userEmail', { deviceId: device.deviceId, userEmail: effectiveUserEmail });
    device.lastSeenEmail = effectiveUserEmail;
    device.userEmail = effectiveUserEmail;

    const existingUser = data.users[effectiveUserEmail];
    if (existingUser && existingUser.companyId) {
      device.companyId = existingUser.companyId;
      device.tenantId = resolveCompanyTenantId(existingUser.companyId);
      device.assignmentStatus = 'assigned';
    } else {
      const domain = effectiveUserEmail.includes('@')
        ? effectiveUserEmail.split('@').pop()
        : '';
      const matchedCompany = Object.values(data.companies).find(
        (company) => company.domain && company.domain === domain,
      );

      if (matchedCompany) {
        if (!existingUser) {
          data.users[effectiveUserEmail] = normalizeUser({
            email: effectiveUserEmail,
            name: '',
            role: 'user',
            isActive: true,
            companyId: matchedCompany.id,
          });
        } else {
          existingUser.companyId = matchedCompany.id;
          existingUser.updatedAt = nowIso();
        }

        device.companyId = matchedCompany.id;
        device.tenantId = resolveCompanyTenantId(matchedCompany.id);
        device.assignmentStatus = 'assigned';
      }
    }
  }

  if (!device.companyId && device.userEmail && data.users[device.userEmail] && data.users[device.userEmail].companyId) {
    const userCompanyId = data.users[device.userEmail].companyId;
    device.companyId = userCompanyId;
    device.tenantId = resolveCompanyTenantId(userCompanyId);
    device.assignmentStatus = 'assigned';
  }

  return device;
}

function resolveCompanyTenantId(companyId) {
  if (!companyId) return null;
  const company = data.companies[companyId];
  if (!company) return null;
  return company.tenantId || company.id;
}

function logAssignment(entry) {
  data.assignments.push({
    ts: entry.ts || nowIso(),
    action: toStr(entry.action) || 'assign',
    actor: toStr(entry.actor) || 'admin',
    deviceId: toStr(entry.deviceId),
    fromCompanyId: toStr(entry.fromCompanyId) || null,
    toCompanyId: toStr(entry.toCompanyId) || null,
    fromUserEmail: toLowerEmail(entry.fromUserEmail) || null,
    toUserEmail: toLowerEmail(entry.toUserEmail) || null,
    fromTenantId: toStr(entry.fromTenantId) || null,
    toTenantId: toStr(entry.toTenantId) || null,
  });

  if (data.assignments.length > 5000) {
    data.assignments = data.assignments.slice(data.assignments.length - 5000);
  }
}

function toDeviceResponse(device) {
  const company = device.companyId ? data.companies[device.companyId] : null;
  const primaryEmail = toLowerEmail(device.userEmail || device.lastSeenEmail) || null;
  const user = primaryEmail ? data.users[primaryEmail] : null;
  const effectiveAllowed = computeEffectiveAllowed(device);
  const graceActive = computeGraceActive(device);

  return {
    ...device,
    primaryEmail,
    userName: user ? user.name : '',
    userRole: user ? user.role : 'user',
    userActive: user ? user.isActive : false,
    companyName: company ? company.name : null,
    effectiveAllowed,
    graceActive,
  };
}

function buildCompanyIdentityRows(companyId) {
  const company = data.companies[companyId];
  if (!company) return [];

  const users = Object.values(data.users).filter((user) => user.companyId === companyId);
  const devices = Object.values(data.devices).filter((device) => {
    if (device.companyId === companyId) return true;
    const email = toLowerEmail(device.userEmail || device.lastSeenEmail);
    return !!email && users.some((user) => user.email === email);
  });

  const devicesByEmail = {};
  for (const device of devices) {
    const email = toLowerEmail(device.userEmail || device.lastSeenEmail);
    if (!email) continue;
    if (!devicesByEmail[email]) devicesByEmail[email] = [];
    devicesByEmail[email].push(device);
  }

  const allEmails = new Set([
    ...users.map((user) => user.email),
    ...Object.keys(devicesByEmail),
  ]);

  const rows = [];
  for (const email of allEmails) {
    const user = data.users[email] || normalizeUser({ email, name: '', companyId, role: 'user', isActive: true });
    const userDevices = (devicesByEmail[email] || []).sort((a, b) => String(b.lastSeen || '').localeCompare(String(a.lastSeen || '')));

    if (!userDevices.length) {
      rows.push({
        email,
        deviceId: null,
        name: user.name || '',
        role: user.role || 'user',
        status: user.isActive ? 'active' : 'inactive',
        devices: 0,
        companyId,
        tenantId: company.tenantId || company.id,
        canAssign: true,
      });
      continue;
    }

    for (const device of userDevices) {
      const effectiveAllowed = computeEffectiveAllowed(device);
      rows.push({
        email,
        deviceId: device.deviceId,
        name: user.name || '',
        role: user.role || 'user',
        status: user.isActive && effectiveAllowed ? 'active' : 'inactive',
        devices: userDevices.length,
        companyId,
        tenantId: device.tenantId || company.tenantId || company.id,
        effectiveAllowed,
        graceActive: computeGraceActive(device),
        lastSeen: device.lastSeen || null,
      });
    }
  }

  return rows.sort((a, b) => {
    const byEmail = String(a.email).localeCompare(String(b.email));
    if (byEmail !== 0) return byEmail;
    return String(b.lastSeen || '').localeCompare(String(a.lastSeen || ''));
  });
}

function deepMerge(baseValue, overrideValue) {
  if (Array.isArray(overrideValue)) return [...overrideValue];
  if (!overrideValue || typeof overrideValue !== 'object') {
    return overrideValue === undefined ? baseValue : overrideValue;
  }

  const base = baseValue && typeof baseValue === 'object' && !Array.isArray(baseValue)
    ? { ...baseValue }
    : {};

  for (const [key, value] of Object.entries(overrideValue)) {
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      base[key] = deepMerge(base[key], value);
    } else {
      base[key] = Array.isArray(value) ? [...value] : value;
    }
  }

  return base;
}

function platformDefaultConfig() {
  return {
    folderNamingTemplate: PLATFORM_DEFAULTS.defaultFolderNamingTemplate,
    fileNamingTemplate: PLATFORM_DEFAULTS.defaultFileNamingTemplate,
    fields: [...PLATFORM_DEFAULTS.defaultFields],
    photoVariables: [...PLATFORM_DEFAULTS.defaultPhotoVariables],
    dropdownPhotoVariables: {},
    uploadTargets: [...PLATFORM_DEFAULTS.defaultStorageTargets],
  };
}

function resolveEffectiveConfig({ company, user, device }) {
  const companyConfig = normalizeCompanyConfig(company && company.config);
  const tenantId = toStr(device && device.tenantId) || toStr(company && company.tenantId) || toStr(company && company.id) || PLATFORM_DEFAULTS.defaultTenantId;
  const tenantConfig = data.tenantConfigs[tenantId] || null;

  const tenantTemplate = tenantConfig && Array.isArray(tenantConfig.templates)
    ? tenantConfig.templates.find((tpl) => tpl.templateId === tenantConfig.defaultTemplateId) || tenantConfig.templates[0]
    : null;

  const tenantLayer = tenantTemplate
    ? {
        folderNamingTemplate: toStr(tenantTemplate.folderPattern) || companyConfig.folderNamingTemplate,
        fileNamingTemplate: toStr(tenantTemplate.fileNamePattern) || companyConfig.fileNamingTemplate,
        photoVariables: normalizeArray(tenantTemplate.captureSteps).map((step) => toStr(step.label)).filter(Boolean),
        dropdownPhotoVariables: normalizeDropdownPhotoVariables(
          tenantTemplate.dropdownPhotoVariables,
          companyConfig.fields
        ),
        uploadTargets: normalizeArray(tenantConfig.storageTargets),
      }
    : {};

  const userLayer = user
    ? {
        preferredTenantId: toStr(user.companyId ? (data.companies[user.companyId] && data.companies[user.companyId].tenantId) : ''),
      }
    : {};

  const deviceLayer = device
    ? {
        deviceId: device.deviceId,
        installationId: device.installationId || null,
      }
    : {};

  const effective = deepMerge(
    deepMerge(
      deepMerge(platformDefaultConfig(), companyConfig),
      tenantLayer,
    ),
    {
      ...userLayer,
      ...deviceLayer,
    },
  );

  return {
    tenantId,
    effective,
    layers: {
      platform: platformDefaultConfig(),
      company: companyConfig,
      tenant: tenantConfig,
      user: user || null,
      device: device || null,
    },
  };
}

function sanitizeDomainTenantMapping(input) {
  const output = {};
  if (!input || typeof input !== 'object') return output;
  for (const [domain, tenantId] of Object.entries(input)) {
    const d = toStr(domain).toLowerCase();
    const t = toStr(tenantId);
    if (d && t) output[d] = t;
  }
  return output;
}

function setNoStoreHeaders(res) {
  res.set('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
  res.set('Pragma', 'no-cache');
  res.set('Expires', '0');
}

// ============================================================================
// BASIC ROUTES
// ============================================================================

app.get('/', (_req, res) => {
  res.redirect('/admin');
});

function sendAdminDashboard(res) {
  setNoStoreHeaders(res);
  res.set('Content-Type', 'text/html; charset=utf-8');
  return res.sendFile(DASHBOARD_FILE);
}

app.get('/admin', (_req, res) => {
  return sendAdminDashboard(res);
});

app.get('/admin/dashboard', (_req, res) => {
  return sendAdminDashboard(res);
});

app.get('/admin/dashboard.html', (_req, res) => {
  return sendAdminDashboard(res);
});

app.get('/admin/index.html', (_req, res) => {
  return sendAdminDashboard(res);
});

app.get('/admin/api/debug-mode', (_req, res) => {
  res.json({ debugMode: isDebugModeEnabled() });
});

app.put('/admin/api/debug-mode', (req, res) => {
  data.debugMode = toBool(req.body && req.body.debugMode, false);
  if (!saveData()) return res.status(500).json({ error: 'Failed to save' });
  return res.json({ success: true, debugMode: isDebugModeEnabled() });
});

// ============================================================================
// PUBLIC API - DEVICE ACCESS
// ============================================================================

app.get('/v1/access/:deviceId', (req, res) => {
  setNoStoreHeaders(res);

  const deviceId = toStr(req.params.deviceId);
  const meta = readDeviceMeta(req);
  if (!deviceId) {
    return res.status(400).json({ error: 'deviceId required' });
  }

  const device = getOrCreateDevice(deviceId, req);
  if (!saveData()) {
    return res.status(500).json({ error: 'Failed to save' });
  }

  const effectiveAllowed = computeEffectiveAllowed(device);
  const graceActive = computeGraceActive(device);
  const assignmentStateVersion = computeAssignmentStateVersion(device);
  const assignmentChanged =
    !!meta.assignmentStateVersion &&
    meta.assignmentStateVersion !== assignmentStateVersion;

  res.set('x-assignment-state-version', assignmentStateVersion);

  return res.json({
    deviceId: device.deviceId,
    allowed: effectiveAllowed,
    effectiveAllowed,
    graceActive,
    graceUntil: device.graceUntil,
    message: device.message || '',
    minVersion: 0,
    companyId: device.companyId || null,
    tenantId: device.tenantId || null,
    assignmentStatus: device.assignmentStatus || (device.companyId ? 'assigned' : 'unassigned'),
    assignmentUpdatedAt: device.assignmentUpdatedAt || null,
    assignmentStateVersion,
    assignmentChanged,
  });
});

app.get('/v1/config/:deviceId', (req, res) => {
  setNoStoreHeaders(res);

  const deviceId = toStr(req.params.deviceId);
  if (!deviceId) {
    return res.status(400).json({ error: 'deviceId required' });
  }

  const device = getOrCreateDevice(deviceId, req);
  if (!saveData()) {
    return res.status(500).json({ error: 'Failed to save' });
  }

  if (!device.companyId) {
    return res.status(404).json({
      error: 'Device not assigned to company yet',
      hint: 'Admin needs to assign this device to a company in the dashboard',
      deviceId,
    });
  }

  const company = data.companies[device.companyId];
  if (!company) {
    return res.status(404).json({ error: 'Company not found' });
  }

  const resolvedTenantId = device.tenantId || company.tenantId || company.id;
  const refreshedTenant = refreshTenantConfigFromOverride(resolvedTenantId, {
    sourceCompanyId: company.id,
    managedBy: 'company-sync+file-override',
    persist: false,
  });
  if (refreshedTenant.changed) {
    saveData();
  }

  const effectiveTenantConfigRaw = refreshedTenant.config || data.tenantConfigs[resolvedTenantId] || null;
  const effectiveTenantConfig = normalizeTenantConfigForResponse(effectiveTenantConfigRaw);
  const configVersion = toStr(
    (effectiveTenantConfig && effectiveTenantConfig.updatedAt) ||
      (company && company.updatedAt) ||
      nowIso(),
  );
  const configStateVersion = computeConfigStateVersion(company, effectiveTenantConfig);
  res.set('x-config-version', configVersion);
  res.set('x-config-state-version', configStateVersion);

  return res.json({
    companyId: company.id,
    companyName: company.name,
    tenantId: resolvedTenantId,
    version: '1.0.0',
    config: normalizeCompanyConfig(company.config || {}),
    effectiveTenantConfig,
    resolution: {
      sources: ['platformDefaults', 'companyConfig', 'tenantConfig'],
      usedTenantId: resolvedTenantId,
      usedCompanyId: company.id,
      fallbackApplied: !effectiveTenantConfig,
    },
    configStateVersion,
  });
});

app.get('/v1/config-version/:deviceId', (req, res) => {
  setNoStoreHeaders(res);

  const deviceId = toStr(req.params.deviceId);
  if (!deviceId) {
    return res.status(400).json({ error: 'deviceId required' });
  }

  const device = getOrCreateDevice(deviceId, req);
  if (!saveData()) {
    return res.status(500).json({ error: 'Failed to save' });
  }

  if (!device.companyId) {
    return res.status(404).json({
      error: 'Device not assigned to company yet',
      hint: 'Admin needs to assign this device to a company in the dashboard',
      deviceId,
    });
  }

  const company = data.companies[device.companyId];
  if (!company) {
    return res.status(404).json({ error: 'Company not found' });
  }

  const resolvedTenantId = device.tenantId || company.tenantId || company.id;
  const refreshedTenant = refreshTenantConfigFromOverride(resolvedTenantId, {
    sourceCompanyId: company.id,
    managedBy: 'company-sync+file-override',
    persist: false,
  });
  if (refreshedTenant.changed) {
    saveData();
  }

  const effectiveTenantConfigRaw = refreshedTenant.config || data.tenantConfigs[resolvedTenantId] || null;
  const effectiveTenantConfig = normalizeTenantConfigForResponse(effectiveTenantConfigRaw);
  const configVersion = toStr(
    (effectiveTenantConfig && effectiveTenantConfig.updatedAt) ||
      (company && company.updatedAt) ||
      nowIso(),
  );
  const configStateVersion = computeConfigStateVersion(company, effectiveTenantConfig);

  res.set('x-config-version', configVersion);
  res.set('x-config-state-version', configStateVersion);

  return res.json({
    deviceId: device.deviceId,
    companyId: company.id,
    tenantId: resolvedTenantId,
    version: configVersion,
    configStateVersion,
    assignmentStateVersion: computeAssignmentStateVersion(device),
  });
});

// ============================================================================
// PUBLIC API - TENANT CONFIG
// ============================================================================

app.get('/v1/tenant-routing', (_req, res) => {
  setNoStoreHeaders(res);

  const emailTenantMapping = buildEmailTenantMapping();

  res.json({
    defaultTenantId: data.defaultTenantId || 'gravit_default',
    manualTenantId: data.manualTenantId || '',
    domainTenantMapping: data.domainTenantMapping || {},
    emailTenantMapping,
  });
});

app.get('/v1/tenant-config/:tenantId', (req, res) => {
  setNoStoreHeaders(res);

  const tenantId = toStr(req.params.tenantId);
  let sourceCompany = Object.values(data.companies).find(
    (company) => toStr(company.tenantId) === tenantId || company.id === tenantId,
  );
  let config = data.tenantConfigs[tenantId];

  if (!config) {
    if (sourceCompany) {
      syncCompanyDerivedState(sourceCompany);
      config = data.tenantConfigs[tenantId] || null;
      saveData();
    }
  }

  if (!sourceCompany) {
    sourceCompany = Object.values(data.companies).find(
      (company) => toStr(company.tenantId) === tenantId || company.id === tenantId,
    );
  }

  const refreshed = refreshTenantConfigFromOverride(tenantId, {
    sourceCompanyId: sourceCompany ? sourceCompany.id : toStr(config && config.sourceCompanyId),
    managedBy: sourceCompany ? 'company-sync+file-override' : 'file-override',
    persist: false,
  });
  if (refreshed.changed) {
    saveData();
  }
  if (refreshed.config) {
    config = refreshed.config;
  }

  if (!config) {
    return res.status(404).json({
      error: 'Tenant config not found',
      tenantId,
      available: Object.keys(data.tenantConfigs || {}),
    });
  }

  const normalizedConfig = normalizeTenantConfigForResponse(config);
  res.set('x-config-version', toStr((normalizedConfig && normalizedConfig.updatedAt) || config.updatedAt || nowIso()));

  return res.json(normalizedConfig || config);
});

// ============================================================================
// ADMIN API - DEVICES
// ============================================================================

app.get('/admin/api/devices', (_req, res) => {
  const devices = Object.values(data.devices)
    .map(toDeviceResponse)
    .sort((a, b) => String(b.lastSeen || '').localeCompare(String(a.lastSeen || '')));

  res.json({ devices });
});

app.post('/admin/api/device-aliases/cleanup', (req, res) => {
  const dryRun = req.body && req.body.dryRun !== undefined
    ? toBool(req.body.dryRun, true)
    : true;

  const result = cleanupDeviceAliases({ dryRun });

  if (!dryRun) {
    if (!saveData()) return res.status(500).json({ error: 'Failed to save alias cleanup result' });
  }

  return res.json({
    success: true,
    ...result,
  });
});

app.post('/admin/api/allow', (req, res) => {
  const deviceId = toStr(req.body && req.body.deviceId);
  if (!deviceId) return res.status(400).json({ error: 'deviceId required' });

  const device = data.devices[deviceId];
  if (!device) return res.status(404).json({ error: 'Device not found' });

  device.allowed = true;
  device.graceUntil = null;
  if (req.body && req.body.message !== undefined) {
    device.message = toStr(req.body.message);
  }
  device.updatedAt = nowIso();

  if (!saveData()) return res.status(500).json({ error: 'Failed to save' });
  return res.json({ success: true, device: toDeviceResponse(device) });
});

app.post('/admin/api/block', (req, res) => {
  const deviceId = toStr(req.body && req.body.deviceId);
  if (!deviceId) return res.status(400).json({ error: 'deviceId required' });

  const device = data.devices[deviceId];
  if (!device) return res.status(404).json({ error: 'Device not found' });

  const graceHours = Number(req.body && req.body.graceHours);
  device.allowed = false;

  if (Number.isFinite(graceHours) && graceHours > 0) {
    const until = new Date(Date.now() + graceHours * 60 * 60 * 1000);
    device.graceUntil = until.toISOString();
  } else {
    device.graceUntil = null;
  }

  if (req.body && req.body.message !== undefined) {
    device.message = toStr(req.body.message);
  }
  device.updatedAt = nowIso();

  if (!saveData()) return res.status(500).json({ error: 'Failed to save' });
  return res.json({ success: true, device: toDeviceResponse(device) });
});

app.post('/admin/api/devices/:deviceId/assign', (req, res) => {
  const deviceId = toStr(req.params.deviceId);
  const companyId = toStr(req.body && req.body.companyId);
  const providedUserEmail = toLowerEmail(req.body && req.body.userEmail) || null;
  const actor = toStr(req.body && req.body.actor) || 'admin';

  if (!deviceId || !companyId) {
    return res.status(400).json({ error: 'deviceId and companyId required' });
  }

  const device = data.devices[deviceId];
  if (!device) return res.status(404).json({ error: 'Device not found' });

  const company = data.companies[companyId];
  if (!company) return res.status(404).json({ error: 'Company not found' });
  if (!company.isActive) return res.status(400).json({ error: 'Company is inactive' });

  const userEmail =
    providedUserEmail ||
    toLowerEmail(device.lastSeenEmail) ||
    toLowerEmail(device.userEmail) ||
    null;

  debugLog('Assign requested', {
    deviceId,
    companyId,
    actor,
    providedUserEmail,
    resolvedUserEmail: userEmail,
  });

  if (userEmail) {
    const existingUser = data.users[userEmail];
    if (existingUser && existingUser.companyId && existingUser.companyId !== companyId) {
      return res.status(400).json({ error: 'User belongs to another company' });
    }

    if (!existingUser) {
      data.users[userEmail] = normalizeUser({
        email: userEmail,
        name: '',
        companyId,
        role: 'user',
        isActive: true,
      });
    } else {
      existingUser.companyId = companyId;
      existingUser.updatedAt = nowIso();
    }
  }

  const previousCompanyId = device.companyId || null;
  const previousUserEmail = device.userEmail || null;
  const previousTenantId = device.tenantId || null;

  device.companyId = companyId;
  device.tenantId = resolveCompanyTenantId(companyId);
  device.userEmail = userEmail || device.userEmail || null;
  device.lastSeenEmail = device.lastSeenEmail || userEmail || device.userEmail || null;
  device.assignmentStatus = 'assigned';
  device.assignmentUpdatedAt = nowIso();
  device.assignmentUpdatedBy = actor;
  device.updatedAt = nowIso();

  logAssignment({
    action: 'assign',
    actor,
    deviceId,
    fromCompanyId: previousCompanyId,
    toCompanyId: companyId,
    fromUserEmail: previousUserEmail,
    toUserEmail: userEmail || previousUserEmail,
    fromTenantId: previousTenantId,
    toTenantId: device.tenantId,
  });

  if (!saveData()) return res.status(500).json({ error: 'Failed to save' });
  return res.json({ success: true, device: toDeviceResponse(device) });
});

app.post('/admin/api/devices/:deviceId/unassign', (req, res) => {
  const deviceId = toStr(req.params.deviceId);
  const actor = toStr(req.body && req.body.actor) || 'admin';
  if (!deviceId) return res.status(400).json({ error: 'deviceId required' });

  const device = data.devices[deviceId];
  if (!device) return res.status(404).json({ error: 'Device not found' });

  const previousCompanyId = device.companyId || null;
  const previousUserEmail = device.userEmail || null;
  const previousTenantId = device.tenantId || null;

  device.companyId = null;
  device.tenantId = null;
  device.userEmail = null;
  device.assignmentStatus = 'unassigned';
  device.assignmentUpdatedAt = nowIso();
  device.assignmentUpdatedBy = actor;
  device.updatedAt = nowIso();

  logAssignment({
    action: 'unassign',
    actor,
    deviceId,
    fromCompanyId: previousCompanyId,
    toCompanyId: null,
    fromUserEmail: previousUserEmail,
    toUserEmail: null,
    fromTenantId: previousTenantId,
    toTenantId: null,
  });

  if (!saveData()) return res.status(500).json({ error: 'Failed to save' });
  return res.json({ success: true, device: toDeviceResponse(device) });
});

app.post('/admin/api/devices/:deviceId/purge-user', (req, res) => {
  const requestedDeviceId = toStr(req.params.deviceId);
  const actor = toStr(req.body && req.body.actor) || 'admin';
  if (!requestedDeviceId) return res.status(400).json({ error: 'deviceId required' });

  const canonicalDeviceId = resolveCanonicalDeviceId(requestedDeviceId) || requestedDeviceId;
  const device = data.devices[canonicalDeviceId] || data.devices[requestedDeviceId];
  if (!device) return res.status(404).json({ error: 'Device not found' });

  const providedUserEmail = toLowerEmail(req.body && req.body.userEmail) || null;
  const targetUserEmail =
    providedUserEmail ||
    toLowerEmail(device.userEmail || device.lastSeenEmail) ||
    null;

  const removableDeviceIds = new Set();
  if (targetUserEmail) {
    for (const candidate of Object.values(data.devices || {})) {
      const candidateEmail = toLowerEmail(candidate.userEmail || candidate.lastSeenEmail) || null;
      if (candidateEmail === targetUserEmail) {
        removableDeviceIds.add(candidate.deviceId);
      }
    }
  }

  if (removableDeviceIds.size === 0) {
    removableDeviceIds.add(canonicalDeviceId);
  }

  const removedDeviceIds = [];
  for (const deviceId of removableDeviceIds) {
    if (data.devices[deviceId]) {
      removedDeviceIds.push(deviceId);
      delete data.devices[deviceId];
    }
  }

  let removedUser = false;
  if (targetUserEmail && data.users[targetUserEmail]) {
    delete data.users[targetUserEmail];
    removedUser = true;
  }

  const assignmentCountBefore = Array.isArray(data.assignments) ? data.assignments.length : 0;
  data.assignments = (Array.isArray(data.assignments) ? data.assignments : []).filter((entry) => {
    const entryDeviceId = toStr(entry && entry.deviceId);
    if (entryDeviceId && removableDeviceIds.has(entryDeviceId)) return false;

    if (targetUserEmail) {
      const fromEmail = toLowerEmail(entry && entry.fromUserEmail);
      const toEmail = toLowerEmail(entry && entry.toUserEmail);
      if (fromEmail === targetUserEmail || toEmail === targetUserEmail) return false;
    }

    return true;
  });
  const removedAssignments = assignmentCountBefore - data.assignments.length;

  let removedAliases = 0;
  const aliases = data.deviceAliases && typeof data.deviceAliases === 'object'
    ? data.deviceAliases
    : {};
  for (const [aliasId, mappedId] of Object.entries(aliases)) {
    const alias = toStr(aliasId);
    const mapped = resolveCanonicalDeviceId(mappedId) || toStr(mappedId);
    if (removableDeviceIds.has(alias) || removableDeviceIds.has(mapped)) {
      delete aliases[aliasId];
      removedAliases += 1;
    }
  }
  data.deviceAliases = aliases;

  debugLog('Purge user requested', {
    actor,
    requestedDeviceId,
    canonicalDeviceId,
    targetUserEmail,
    removedDeviceIds,
    removedUser,
    removedAssignments,
    removedAliases,
  });

  if (!saveData()) return res.status(500).json({ error: 'Failed to save' });
  return res.json({
    success: true,
    actor,
    requestedDeviceId,
    canonicalDeviceId,
    targetUserEmail,
    removedUser,
    removedDeviceIds,
    removedAssignments,
    removedAliases,
  });
});

app.get('/admin/api/assignments', (_req, res) => {
  const assignments = [...data.assignments].sort((a, b) => String(b.ts).localeCompare(String(a.ts)));
  res.json({ assignments });
});

// ============================================================================
// ADMIN API - COMPANIES
// ============================================================================

app.get('/admin/api/companies', (_req, res) => {
  const companies = Object.values(data.companies).sort((a, b) => a.name.localeCompare(b.name));
  res.json({ companies });
});

app.post('/admin/api/companies', (req, res) => {
  const id = toStr(req.body && req.body.id);
  const name = toStr(req.body && req.body.name);
  const domain = toStr(req.body && req.body.domain).toLowerCase();
  const tenantId = toStr(req.body && req.body.tenantId) || id;

  if (!id || !name || !domain) {
    return res.status(400).json({ error: 'Missing required fields: id, name, domain' });
  }

  if (data.companies[id]) {
    return res.status(409).json({ error: 'Company with this ID already exists' });
  }

  const configPayload = req.body && typeof req.body.config === 'object' ? req.body.config : {};
  const configValidationErrors = validateCompanyConfigInput(configPayload);
  if (configValidationErrors.length) {
    return validationError(res, configValidationErrors);
  }

  data.companies[id] = normalizeCompany({
    id,
    name,
    domain,
    tenantId,
    isActive: req.body && req.body.isActive !== undefined ? req.body.isActive : true,
    config: configPayload,
    createdAt: nowIso(),
    updatedAt: nowIso(),
  });

  syncCompanyDerivedState(data.companies[id]);

  if (!saveData()) return res.status(500).json({ error: 'Failed to save' });
  return res.json({ success: true, company: data.companies[id] });
});

app.put('/admin/api/companies/:id', (req, res) => {
  const id = toStr(req.params.id);
  const company = data.companies[id];
  if (!company) return res.status(404).json({ error: 'Company not found' });

  const nextName = toStr(req.body && req.body.name);
  const nextDomain = toStr(req.body && req.body.domain).toLowerCase();
  const nextTenantId = toStr(req.body && req.body.tenantId);

  if (nextName) company.name = nextName;
  if (nextDomain) company.domain = nextDomain;
  if (nextTenantId) company.tenantId = nextTenantId;
  if (req.body && req.body.isActive !== undefined) {
    company.isActive = toBool(req.body.isActive, company.isActive);
  }
  if (req.body && req.body.config && typeof req.body.config === 'object') {
    const configValidationErrors = validateCompanyConfigInput(req.body.config);
    if (configValidationErrors.length) {
      return validationError(res, configValidationErrors);
    }
    company.config = normalizeCompanyConfig(req.body.config);
  }
  company.updatedAt = nowIso();

  syncCompanyDerivedState(company);

  if (!saveData()) return res.status(500).json({ error: 'Failed to save' });
  return res.json({ success: true, company });
});

app.get('/admin/api/companies/:id/devices', (req, res) => {
  const id = toStr(req.params.id);
  if (!data.companies[id]) return res.status(404).json({ error: 'Company not found' });

  const devices = Object.values(data.devices)
    .filter((device) => device.companyId === id)
    .map(toDeviceResponse)
    .sort((a, b) => String(b.lastSeen || '').localeCompare(String(a.lastSeen || '')));

  res.json({ devices });
});

app.get('/admin/api/companies/:id/users', (req, res) => {
  const id = toStr(req.params.id);
  if (!data.companies[id]) return res.status(404).json({ error: 'Company not found' });

  const users = Object.values(data.users)
    .filter((user) => user.companyId === id)
    .sort((a, b) => a.email.localeCompare(b.email));

  res.json({ users });
});

app.get('/admin/api/companies/:id/identity-rows', (req, res) => {
  const id = toStr(req.params.id);
  if (!data.companies[id]) return res.status(404).json({ error: 'Company not found' });

  const rows = buildCompanyIdentityRows(id);
  res.json({ rows });
});

// ============================================================================
// ADMIN API - USERS
// ============================================================================

app.get('/admin/api/users', (_req, res) => {
  const users = Object.values(data.users)
    .map((user) => {
      const deviceIds = Object.values(data.devices)
        .filter((d) => toLowerEmail(d.userEmail || d.lastSeenEmail) === user.email)
        .map((d) => d.deviceId)
        .sort();
      return {
        ...user,
        assignedDeviceCount: deviceIds.length,
        deviceIds,
      };
    })
    .sort((a, b) => a.email.localeCompare(b.email));

  res.json({ users });
});

app.post('/admin/api/users', (req, res) => {
  const email = toLowerEmail(req.body && req.body.email);
  const companyId = toStr(req.body && req.body.companyId) || null;

  if (!email) return res.status(400).json({ error: 'email required' });
  if (data.users[email]) return res.status(409).json({ error: 'User already exists' });

  if (companyId && !data.companies[companyId]) {
    return res.status(404).json({ error: 'Company not found' });
  }

  data.users[email] = normalizeUser({
    email,
    name: toStr(req.body && req.body.name),
    role: toStr(req.body && req.body.role) || 'user',
    companyId,
    isActive: req.body && req.body.isActive !== undefined ? req.body.isActive : true,
    createdAt: nowIso(),
    updatedAt: nowIso(),
  });

  if (!saveData()) return res.status(500).json({ error: 'Failed to save' });
  return res.json({ success: true, user: data.users[email] });
});

app.put('/admin/api/users/:email', (req, res) => {
  const email = toLowerEmail(req.params.email);
  const user = data.users[email];
  if (!user) return res.status(404).json({ error: 'User not found' });

  const nextCompanyId = toStr(req.body && req.body.companyId);
  if (nextCompanyId && !data.companies[nextCompanyId]) {
    return res.status(404).json({ error: 'Company not found' });
  }

  const nextName = toStr(req.body && req.body.name);
  const nextRole = toStr(req.body && req.body.role);

  if (nextName || nextName === '') user.name = nextName;
  if (nextRole) user.role = nextRole;
  if (req.body && req.body.companyId !== undefined) {
    user.companyId = nextCompanyId || null;
  }
  if (req.body && req.body.isActive !== undefined) {
    user.isActive = toBool(req.body.isActive, user.isActive);
  }

  user.updatedAt = nowIso();

  if (!saveData()) return res.status(500).json({ error: 'Failed to save' });
  return res.json({ success: true, user });
});

// ============================================================================
// ADMIN API - TENANT CONFIGS
// ============================================================================

app.get('/admin/api/tenants', (_req, res) => {
  const tenants = Object.values(data.tenantConfigs)
    .sort((a, b) => String(a.tenantId || '').localeCompare(String(b.tenantId || '')));
  res.json({ tenants });
});

app.post('/admin/api/tenants', (req, res) => {
  const payload = req.body && typeof req.body === 'object' ? req.body : {};
  const tenantId = toStr(payload.tenantId);
  if (!tenantId) return res.status(400).json({ error: 'tenantId required' });

  if (data.tenantConfigs[tenantId]) {
    return res.status(409).json({ error: 'Tenant config already exists' });
  }

  const tenantValidationErrors = validateTenantPayloadInput(payload, {});
  if (tenantValidationErrors.length) {
    return validationError(res, tenantValidationErrors);
  }

  const normalizedPayload = normalizeTenantConfigForResponse({
    ...payload,
    tenantId,
  }) || {
    ...payload,
    tenantId,
  };

  data.tenantConfigs[tenantId] = {
    ...normalizedPayload,
    tenantId,
    createdAt: nowIso(),
    updatedAt: nowIso(),
  };

  if (!saveData()) return res.status(500).json({ error: 'Failed to save' });
  return res.json({ success: true, tenant: data.tenantConfigs[tenantId] });
});

app.put('/admin/api/tenants/:id', (req, res) => {
  const id = toStr(req.params.id);
  const existing = data.tenantConfigs[id];
  if (!existing) {
    return res.status(404).json({ error: 'Tenant config not found' });
  }

  const updates = req.body && typeof req.body === 'object' ? req.body : {};
  const tenantValidationErrors = validateTenantPayloadInput(updates, existing);
  if (tenantValidationErrors.length) {
    return validationError(res, tenantValidationErrors);
  }

  const normalizedUpdates = normalizeTenantConfigForResponse({
    ...existing,
    ...updates,
    tenantId: id,
  }) || {
    ...existing,
    ...updates,
    tenantId: id,
  };

  data.tenantConfigs[id] = {
    ...normalizedUpdates,
    tenantId: id,
    updatedAt: nowIso(),
  };

  if (!saveData()) return res.status(500).json({ error: 'Failed to save' });
  return res.json({ success: true, tenant: data.tenantConfigs[id] });
});

app.post('/admin/api/onboarding/save', (req, res) => {
  const payload = req.body && typeof req.body === 'object' ? req.body : {};

  const companyId = toStr(payload.companyId);
  const companyName = toStr(payload.companyName);
  const primaryDomain = toStr(payload.primaryDomain).toLowerCase();
  const tenantId = toStr(payload.tenantId);
  const extraDomains = toStringList(payload.extraDomains).map((domain) => toStr(domain).toLowerCase());
  const companyConfig = payload.companyConfig && typeof payload.companyConfig === 'object'
    ? payload.companyConfig
    : {};
  const tenantPayload = payload.tenantPayload && typeof payload.tenantPayload === 'object'
    ? payload.tenantPayload
    : {};

  if (!companyId || !companyName || !primaryDomain || !tenantId) {
    return res.status(400).json({ error: 'Missing required fields: companyId, companyName, primaryDomain, tenantId' });
  }

  const errors = [
    ...validateCompanyConfigInput(companyConfig),
    ...validateTenantPayloadInput({ ...tenantPayload, tenantId }, data.tenantConfigs[tenantId] || {}),
  ];
  if (errors.length) {
    return validationError(res, errors);
  }

  const snapshot = cloneDataState(data);

  try {
    const existingCompany = data.companies[companyId] || null;
    const previousPrimaryDomain = toStr(existingCompany && existingCompany.domain).toLowerCase();
    const previousTenantId = toStr(existingCompany && existingCompany.tenantId) || companyId;

    const baseCompany = existingCompany || {
      id: companyId,
      createdAt: nowIso(),
    };

    const nextCompany = normalizeCompany({
      ...baseCompany,
      id: companyId,
      name: companyName,
      domain: primaryDomain,
      tenantId,
      isActive: payload.isActive !== undefined ? payload.isActive : (baseCompany.isActive !== undefined ? baseCompany.isActive : true),
      config: companyConfig,
      updatedAt: nowIso(),
    });

    data.companies[companyId] = nextCompany;
    syncCompanyDerivedState(nextCompany);

    const routingMapping = {
      ...(data.domainTenantMapping && typeof data.domainTenantMapping === 'object' ? data.domainTenantMapping : {}),
    };
    const domains = [...new Set([primaryDomain, ...extraDomains].map((domain) => toStr(domain).toLowerCase()).filter(Boolean))];
    domains.forEach((domain) => {
      routingMapping[domain] = tenantId;
    });

    if (
      previousPrimaryDomain &&
      previousPrimaryDomain !== primaryDomain &&
      routingMapping[previousPrimaryDomain] === previousTenantId
    ) {
      delete routingMapping[previousPrimaryDomain];
    }

    data.domainTenantMapping = sanitizeDomainTenantMapping(routingMapping);

    const existingTenant = data.tenantConfigs[tenantId] || null;
    const normalizedTenantPayload = normalizeTenantConfigForResponse({
      ...(existingTenant || {}),
      ...tenantPayload,
      tenantId,
    }) || {
      ...(existingTenant || {}),
      ...tenantPayload,
      tenantId,
    };

    data.tenantConfigs[tenantId] = {
      ...normalizedTenantPayload,
      tenantId,
      createdAt: (existingTenant && existingTenant.createdAt) || nowIso(),
      updatedAt: nowIso(),
    };

    if (!saveData()) {
      throw new Error('Failed to save onboarding payload');
    }

    return res.json({
      success: true,
      company: data.companies[companyId],
      tenant: data.tenantConfigs[tenantId],
      routing: {
        defaultTenantId: data.defaultTenantId,
        manualTenantId: data.manualTenantId,
        domainTenantMapping: data.domainTenantMapping,
      },
    });
  } catch (err) {
    restoreDataState(snapshot);
    return res.status(500).json({ error: err.message || 'Failed to save onboarding data' });
  }
});

app.delete('/admin/api/tenants/:id', (req, res) => {
  const id = toStr(req.params.id);
  if (!data.tenantConfigs[id]) {
    return res.status(404).json({ error: 'Tenant config not found' });
  }

  delete data.tenantConfigs[id];

  if (data.defaultTenantId === id) {
    const fallback = Object.keys(data.tenantConfigs)[0] || 'gravit_default';
    data.defaultTenantId = fallback;
  }

  const cleanedMapping = {};
  for (const [domain, tenantId] of Object.entries(data.domainTenantMapping)) {
    if (tenantId !== id) cleanedMapping[domain] = tenantId;
  }
  data.domainTenantMapping = cleanedMapping;

  if (!saveData()) return res.status(500).json({ error: 'Failed to save' });
  return res.json({ success: true });
});

app.put('/admin/api/tenant-routing', (req, res) => {
  const defaultTenantId = toStr(req.body && req.body.defaultTenantId);
  const manualTenantId = toStr(req.body && req.body.manualTenantId);
  const domainTenantMapping = sanitizeDomainTenantMapping(req.body && req.body.domainTenantMapping);

  if (defaultTenantId) {
    data.defaultTenantId = defaultTenantId;
  }
  data.manualTenantId = manualTenantId;
  data.domainTenantMapping = domainTenantMapping;

  if (!saveData()) return res.status(500).json({ error: 'Failed to save' });
  return res.json({
    success: true,
    defaultTenantId: data.defaultTenantId,
    manualTenantId: data.manualTenantId,
    domainTenantMapping: data.domainTenantMapping,
  });
});

app.get('/admin/api/effective-config', (req, res) => {
  const companyId = toStr(req.query && req.query.companyId);
  const userEmail = toLowerEmail(req.query && req.query.userEmail) || null;
  const deviceId = toStr(req.query && req.query.deviceId);

  const device = deviceId ? data.devices[deviceId] || null : null;
  const user = userEmail ? data.users[userEmail] || null : (device && device.userEmail ? data.users[toLowerEmail(device.userEmail)] || null : null);
  const company = companyId
    ? data.companies[companyId] || null
    : (device && device.companyId ? data.companies[device.companyId] || null : (user && user.companyId ? data.companies[user.companyId] || null : null));

  if (!company) {
    return res.status(404).json({
      error: 'Company context not found',
      hint: 'Provide companyId or a linked userEmail/deviceId',
    });
  }

  const resolved = resolveEffectiveConfig({ company, user, device });
  return res.json({
    companyId: company.id,
    companyName: company.name,
    userEmail: user ? user.email : null,
    deviceId: device ? device.deviceId : null,
    tenantId: resolved.tenantId,
    effectiveConfig: resolved.effective,
    layers: resolved.layers,
  });
});

// ============================================================================
// HEALTH
// ============================================================================

app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    timestamp: nowIso(),
    dataFile: DATA_FILE,
    stats: {
      devices: Object.keys(data.devices || {}).length,
      companies: Object.keys(data.companies || {}).length,
      users: Object.keys(data.users || {}).length,
      tenantConfigs: Object.keys(data.tenantConfigs || {}).length,
      assignments: Array.isArray(data.assignments) ? data.assignments.length : 0,
    },
  });
});

app.listen(PORT, '0.0.0.0', () => {
  if (!ADMIN_AUTH_ENABLED) {
    console.warn('Admin auth disabled. Set ADMIN_AUTH_USERNAME and ADMIN_AUTH_PASSWORD to protect /admin routes.');
  }

  if (normalizedBackupKeepCount() > 0) {
    console.log(`Data backup snapshots enabled: dir=${DATA_BACKUP_DIR}, keep=${normalizedBackupKeepCount()}`);
  } else {
    console.log('Data backup snapshots disabled (DATA_BACKUP_KEEP=0).');
  }

  console.log(`BilderApp API running on port ${PORT}`);
  console.log(`Data file: ${DATA_FILE}`);
});
