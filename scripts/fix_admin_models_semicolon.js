const fs = require('fs');
const path = require('path');
const file = path.join(__dirname, '..', 'lib/screens/admin/admin_models.dart');
let src = fs.readFileSync(file, 'utf8');
const bad = "      case 'pending':\n        return '활성'\n      case 'active':";
const good = "      case 'pending':\n        return '활성';\n      case 'active':";
if (!src.includes(bad)) {
  console.error('pattern not found');
  const i = src.indexOf("case 'pending'");
  console.log(JSON.stringify(src.slice(i, i + 80)));
  process.exit(1);
}
fs.writeFileSync(file, src.replace(bad, good), 'utf8');
console.log('OK');
