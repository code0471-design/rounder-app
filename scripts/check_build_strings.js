const fs = require('fs');
const s = fs.readFileSync('build/web/main.dart.js', 'utf8');

const i = s.indexOf('1~30');
console.log('first 1~30 at', i);
console.log(JSON.stringify(s.slice(i, i + 120)));

// Find Text$("1~30 pattern
const m = s.match(/Text\$\("1~30[^"]{0,120}/);
console.log('match', m && m[0]);

const btn = s.match(/직책[^"]{0,40}/);
console.log('raw hangul 직책', btn && btn[0]);

const middot = s.indexOf('\u00b7');
console.log('raw middot count-ish', middot);

// Look for edit button via unique nearby English
const editIdx = s.indexOf('_buildEditRoleButton');
console.log('_buildEditRoleButton', editIdx);

const nav = s.indexOf('_navigateToEdit');
console.log('_navigateToEdit', nav);

// dart2js keeps some method names? try minified patterns from label
const roleEdit = s.indexOf('ROLE_EDIT_BTN');
console.log('ROLE_EDIT_BTN', roleEdit);
