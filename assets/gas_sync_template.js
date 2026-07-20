// Google Apps Script - Money Manager Partner Sync
// Deploy as: Web App | Execute as: Me | Who has access: Anyone

function doGet(e) {
  try {
    var params = (e && e.parameter) ? e.parameter : {};
    var action = params.action || '';
    
    if (action === 'test') {
      return ContentService.createTextOutput('ok').setMimeType(ContentService.MimeType.TEXT);
    }
    
    var sheet = getOrCreateSheet();
    
    if (action === 'get') {
      var key = params.key;
      if (!key) {
        return ContentService.createTextOutput('error: missing key').setMimeType(ContentService.MimeType.TEXT);
      }
      var val = getValueByKey(sheet, key);
      if (val === null || val === undefined || val === '') {
        return ContentService.createTextOutput('404').setMimeType(ContentService.MimeType.TEXT);
      }
      // Strip the leading apostrophe GAS adds to prevent number conversion
      var result = String(val);
      if (result.charAt(0) === "'") {
        result = result.substring(1);
      }
      return ContentService.createTextOutput(result).setMimeType(ContentService.MimeType.TEXT);
    }
    
    if (action === 'set_chunk') {
      var key = params.key;
      var index = parseInt(params.index, 10);
      var total = parseInt(params.total, 10);
      var val = params.val || '';
      
      if (!key || isNaN(index) || isNaN(total)) {
        return ContentService.createTextOutput('error: missing params').setMimeType(ContentService.MimeType.TEXT);
      }
      
      // Store chunk without leading apostrophe
      var chunkKey = key + '_chunk_' + index;
      setValueByKey(sheet, chunkKey, val);
      
      // Check if all chunks are present
      var allChunks = [];
      var missing = false;
      for (var i = 0; i < total; i++) {
        var cVal = getValueByKey(sheet, key + '_chunk_' + i);
        if (cVal === null || cVal === undefined || cVal === '') {
          missing = true;
          break;
        }
        var cStr = String(cVal);
        if (cStr.charAt(0) === "'") { cStr = cStr.substring(1); }
        allChunks.push(cStr);
      }
      
      if (!missing) {
        var fullVal = allChunks.join('');
        setValueByKey(sheet, key, fullVal);
        // Clean up chunk rows
        for (var j = 0; j < total; j++) {
          deleteRowByKey(sheet, key + '_chunk_' + j);
        }
        return ContentService.createTextOutput('assembled').setMimeType(ContentService.MimeType.TEXT);
      }
      
      return ContentService.createTextOutput('chunk_received').setMimeType(ContentService.MimeType.TEXT);
    }
    
    return ContentService.createTextOutput('error: unknown action: ' + action).setMimeType(ContentService.MimeType.TEXT);
  } catch (err) {
    return ContentService.createTextOutput('error: ' + err.toString()).setMimeType(ContentService.MimeType.TEXT);
  }
}

function getOrCreateSheet() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName('SyncData');
  if (!sheet) {
    sheet = ss.insertSheet('SyncData');
    sheet.appendRow(['Key', 'Value', 'UpdatedAt']);
    sheet.setFrozenRows(1);
    sheet.getRange('B:B').setNumberFormat('@STRING@');
  }
  return sheet;
}

function getValueByKey(sheet, key) {
  var data = sheet.getDataRange().getValues();
  for (var i = 1; i < data.length; i++) {
    if (String(data[i][0]) === String(key)) {
      return data[i][1];
    }
  }
  return null;
}

function setValueByKey(sheet, key, value) {
  var data = sheet.getDataRange().getValues();
  var dateStr = new Date().toISOString();
  var found = false;
  var strVal = String(value);
  
  for (var i = 1; i < data.length; i++) {
    if (String(data[i][0]) === String(key)) {
      if (!found) {
        sheet.getRange(i + 1, 2).setValue(strVal);
        sheet.getRange(i + 1, 3).setValue(dateStr);
        found = true;
      } else {
        sheet.deleteRow(i + 1);
        data.splice(i, 1);
        i--;
      }
    }
  }
  if (!found) {
    sheet.appendRow([key, strVal, dateStr]);
  }
}

function deleteRowByKey(sheet, key) {
  var data = sheet.getDataRange().getValues();
  for (var i = data.length - 1; i >= 1; i--) {
    if (String(data[i][0]) === String(key)) {
      sheet.deleteRow(i + 1);
      data.splice(i, 1);
    }
  }
}
