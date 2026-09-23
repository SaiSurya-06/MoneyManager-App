// Google Apps Script - Money Manager Partner Sync (High-Reliability Engine v2)
// Deploy as: Web App | Execute as: Me | Who has access: Anyone

function doGet(e) {
  try {
    var params = (e && e.parameter) ? e.parameter : {};
    var action = params.action || '';
    
    // Quick health-check: runs without locks for instant response
    if (action === 'test') {
      return ContentService.createTextOutput('ok').setMimeType(ContentService.MimeType.TEXT);
    }
    
    var sheet = getOrCreateSheet();
    
    // Read action
    if (action === 'get') {
      var key = params.key;
      if (!key) {
        return ContentService.createTextOutput('error: missing key').setMimeType(ContentService.MimeType.TEXT);
      }
      var val = getValueByKey(sheet, key);
      if (val === null || val === undefined || val === '') {
        return ContentService.createTextOutput('404').setMimeType(ContentService.MimeType.TEXT);
      }
      return ContentService.createTextOutput(val).setMimeType(ContentService.MimeType.TEXT);
    }
    
    // Write chunk action
    if (action === 'set_chunk') {
      var key = params.key;
      var index = parseInt(params.index, 10);
      var total = parseInt(params.total, 10);
      var val = params.val || '';
      
      if (!key || isNaN(index) || isNaN(total)) {
        return ContentService.createTextOutput('error: missing params').setMimeType(ContentService.MimeType.TEXT);
      }
      
      // Use LockService to prevent race conditions when both partners sync simultaneously
      var lock = LockService.getScriptLock();
      try {
        var hasLock = lock.tryLock(25000);
        if (!hasLock) {
          return ContentService.createTextOutput('error: server busy, please retry').setMimeType(ContentService.MimeType.TEXT);
        }
        
        var chunkKey = key + '_chunk_' + index;
        
        // Single chunk optimization: if total == 1, save directly to the main key
        if (total === 1) {
          setValueByKey(sheet, key, val, [chunkKey]);
          return ContentService.createTextOutput('assembled').setMimeType(ContentService.MimeType.TEXT);
        }
        
        // Save current chunk
        setValueByKey(sheet, chunkKey, val);
        
        // Re-read data to verify all chunks
        var allData = sheet.getDataRange().getValues();
        var chunkMap = {};
        for (var r = 1; r < allData.length; r++) {
          var rowKey = String(allData[r][0]);
          if (rowKey.indexOf(key + '_chunk_') === 0) {
            var cStr = String(allData[r][1]);
            if (cStr.charAt(0) === "'") { cStr = cStr.substring(1); }
            chunkMap[rowKey] = cStr;
          }
        }
        
        // Check if all chunks from 0 to total - 1 exist
        var allPresent = true;
        var fullChunks = [];
        var chunkKeysToDelete = [];
        for (var i = 0; i < total; i++) {
          var cKey = key + '_chunk_' + i;
          chunkKeysToDelete.push(cKey);
          if (!chunkMap[cKey]) {
            allPresent = false;
            break;
          }
          fullChunks.push(chunkMap[cKey]);
        }
        
        if (allPresent) {
          var fullVal = fullChunks.join('');
          // Atomically set fullVal AND remove all chunk rows in a single batch operation
          setValueByKey(sheet, key, fullVal, chunkKeysToDelete);
          return ContentService.createTextOutput('assembled').setMimeType(ContentService.MimeType.TEXT);
        }
        
        return ContentService.createTextOutput('chunk_received').setMimeType(ContentService.MimeType.TEXT);
      } finally {
        lock.releaseLock();
      }
    }
    
    return ContentService.createTextOutput('error: unknown action: ' + action).setMimeType(ContentService.MimeType.TEXT);
  } catch (err) {
    return ContentService.createTextOutput('error: ' + err.toString()).setMimeType(ContentService.MimeType.TEXT);
  }
}

function getOrCreateSheet() {
  var ss = null;
  try {
    ss = SpreadsheetApp.getActiveSpreadsheet();
  } catch(e) {
    ss = null;
  }
  
  if (!ss) {
    var props = PropertiesService.getScriptProperties();
    var ssId = props.getProperty('SPREADSHEET_ID');
    if (ssId) {
      try {
        ss = SpreadsheetApp.openById(ssId);
      } catch(e) {
        ss = null;
      }
    }
    if (!ss) {
      ss = SpreadsheetApp.create('MoneyManager Partner Sync');
      props.setProperty('SPREADSHEET_ID', ss.getId());
    }
  }
  
  var sheet = ss.getSheetByName('SyncData');
  if (!sheet) {
    sheet = ss.insertSheet('SyncData');
    sheet.appendRow(['Key', 'Value', 'UpdatedAt']);
    sheet.setFrozenRows(1);
    sheet.getRange('A:C').setNumberFormat('@');
  }
  return sheet;
}

function getValueByKey(sheet, key) {
  var data = sheet.getDataRange().getValues();
  
  // 1. Direct single-cell lookup
  for (var i = 1; i < data.length; i++) {
    if (String(data[i][0]) === String(key)) {
      var val = data[i][1];
      if (val === null || val === undefined || val === '') return null;
      var str = String(val);
      if (str.charAt(0) === "'") { str = str.substring(1); }
      return str;
    }
  }
  
  // 2. Multi-part lookup (if value exceeded Google Sheets 45,000 char per-cell limit)
  var parts = [];
  var partIdx = 0;
  while (true) {
    var partKey = key + '__p' + partIdx;
    var found = false;
    for (var j = 1; j < data.length; j++) {
      if (String(data[j][0]) === partKey) {
        var pVal = data[j][1];
        if (pVal !== null && pVal !== undefined) {
          var pStr = String(pVal);
          if (pStr.charAt(0) === "'") { pStr = pStr.substring(1); }
          parts.push(pStr);
          found = true;
          break;
        }
      }
    }
    if (!found) break;
    partIdx++;
  }
  
  if (parts.length > 0) {
    return parts.join('');
  }
  
  return null;
}

/**
 * High-performance batch updater:
 * Updates keys and deletes specified keys in ONE atomic memory pass.
 * Automatically splits payloads > 45,000 chars into multiple cells to avoid Google Sheets cell limits.
 * Prepends "'" to prevent Google Sheets from interpreting values as formulas.
 */
function setValueByKey(sheet, key, value, keysToDelete) {
  keysToDelete = keysToDelete || [];
  var data = sheet.getDataRange().getValues();
  var dateStr = new Date().toISOString();
  var strVal = String(value);
  
  var deleteMap = {};
  for (var d = 0; d < keysToDelete.length; d++) {
    deleteMap[keysToDelete[d]] = true;
  }
  
  // Also delete any existing multi-part keys for this key
  for (var p = 0; p < 20; p++) {
    deleteMap[key + '__p' + p] = true;
  }
  deleteMap[key] = true;
  
  var newRows = [];
  if (data.length > 0) {
    newRows.push(data[0]); // Header row
  } else {
    newRows.push(['Key', 'Value', 'UpdatedAt']);
  }
  
  // Filter out deleted / updated rows in memory
  for (var r = 1; r < data.length; r++) {
    var k = String(data[r][0]);
    if (!deleteMap[k]) {
      newRows.push(data[r]);
    }
  }
  
  // Split into parts if string exceeds 45,000 characters
  var MAX_CELL_LEN = 45000;
  if (strVal.length > MAX_CELL_LEN) {
    var partIdx = 0;
    for (var offset = 0; offset < strVal.length; offset += MAX_CELL_LEN) {
      var chunk = strVal.substring(offset, offset + MAX_CELL_LEN);
      newRows.push([key + '__p' + partIdx, "'" + chunk, dateStr]);
      partIdx++;
    }
  } else {
    newRows.push([key, "'" + strVal, dateStr]);
  }
  
  // Atomic single-call write to Google Sheets
  sheet.clearContents();
  sheet.getRange(1, 1, newRows.length, 3).setNumberFormat('@').setValues(newRows);
}
